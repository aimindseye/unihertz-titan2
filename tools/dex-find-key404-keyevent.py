#!/usr/bin/env python3
import re, struct, sys
from pathlib import Path

def u16(b,o): return struct.unpack_from("<H", b, o)[0]
def u32(b,o): return struct.unpack_from("<I", b, o)[0]
def s16(x): return x - 0x10000 if x & 0x8000 else x
def s32(x): return x - 0x100000000 if x & 0x80000000 else x

def uleb(b, off):
    v=s=0
    for _ in range(5):
        x=b[off]; off += 1; v |= (x & 0x7f) << s
        if not x & 0x80: return v,off
        s += 7
    return v,off

def mutf(b,off):
    _,off=uleb(b,off); end=b.find(b"\0",off)
    return b[off:(len(b) if end < 0 else end)].decode("utf-8","replace")

# Code-unit widths for standard DEX opcodes. Payloads are handled separately.
WIDTH=[1]*256
for op in (0x02,0x05,0x08,0x13,0x15,0x16,0x19,0x1a,0x1c,0x1f,0x20,0x22,0x23,
           0x29,0x2d,0x2e,0x2f,0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,
           0x38,0x39,0x3a,0x3b,0x3c,0x3d):
    WIDTH[op]=2
for op in range(0x44,0x6e): WIDTH[op]=2
for op in range(0x90,0xb0): WIDTH[op]=2
for op in range(0xd0,0xe3): WIDTH[op]=2
for op in (0x03,0x06,0x09,0x14,0x17,0x1b,0x24,0x25,0x26,0x2a,0x2b,0x2c,
           0x6e,0x6f,0x70,0x71,0x72,0x74,0x75,0x76,0x77,0x78,0xfc,0xfd):
    WIDTH[op]=3
WIDTH[0x18]=5
WIDTH[0xfa]=4
WIDTH[0xfb]=4
WIDTH[0xfe]=2
WIDTH[0xff]=2

KEY_RE=re.compile(
    r"KeyEvent|dispatchKey|interceptKey|ShortcutInterceptKey|getKeyCode|getScanCode|"
    r"injectInputEvent|onKeyDown|onKeyUp|keyboard|gesture|swipe|touchpad", re.I
)

def iter_insns(units):
    j=0
    while j < len(units):
        word=units[j]
        op=word & 0xff
        hi=(word >> 8) & 0xff
        if op==0 and hi in (1,2,3):
            if hi==1 and j+1 < len(units):
                size=units[j+1]; width=4+2*size
            elif hi==2 and j+1 < len(units):
                size=units[j+1]; width=2+4*size
            elif hi==3 and j+3 < len(units):
                elem=units[j+1]
                size=units[j+2] | (units[j+3] << 16)
                width=4 + ((elem*size + 1)//2)
            else:
                width=1
        else:
            width=WIDTH[op]
        yield j,op
        j += max(1,width)

def scan(path):
    b=Path(path).read_bytes()
    if b[:3] != b"dex": return
    ss,so=u32(b,0x38),u32(b,0x3c)
    ts,to=u32(b,0x40),u32(b,0x44)
    ms,mo=u32(b,0x58),u32(b,0x5c)
    cs,co=u32(b,0x60),u32(b,0x64)
    strings=[mutf(b,u32(b,so+4*i)) for i in range(ss)]
    types=[strings[u32(b,to+4*i)] for i in range(ts)]
    methods=[]
    for i in range(ms):
        q=mo+8*i
        cidx,_,nidx=struct.unpack_from("<HHI",b,q)
        methods.append((
            types[cidx] if cidx < len(types) else f"type#{cidx}",
            strings[nidx] if nidx < len(strings) else f"str#{nidx}"
        ))

    def scan_method(midx, code):
        if not code or code+16 > len(b) or midx >= len(methods): return
        n=u32(b,code+12); start=code+16; end=min(len(b),start+2*n)
        units=[u16(b,x) for x in range(start,end,2)]
        has404=False; refs=[]
        for j,op in iter_insns(units):
            if op==0x13 and j+1 < len(units) and s16(units[j+1])==404:
                has404=True
            elif op==0x14 and j+2 < len(units) and s32(units[j+1] | (units[j+2]<<16))==404:
                has404=True
            if (0x6e <= op <= 0x72 or 0x74 <= op <= 0x78) and j+1 < len(units):
                mi=units[j+1]
                if mi < len(methods): refs.append(methods[mi])
        if not has404: return
        cls,name=methods[midx]
        context=" ".join([cls,name]+[a+" "+n for a,n in refs])
        if KEY_RE.search(context):
            selected=[(a,n) for a,n in refs if KEY_RE.search(a+" "+n)]
            print(f"{path}\t{cls}->{name}\trefs=" +
                  "; ".join(a+"->"+n for a,n in selected[:40]))

    for ci in range(cs):
        q=co+32*ci; cdata=u32(b,q+24)
        if not cdata: continue
        p=cdata
        try:
            sf,p=uleb(b,p); inf,p=uleb(b,p); dm,p=uleb(b,p); vm,p=uleb(b,p)
            for _ in range(sf+inf): _,p=uleb(b,p); _,p=uleb(b,p)

            # DEX method_idx_diff restarts independently for direct and virtual lists.
            midx=0
            for _ in range(dm):
                d,p=uleb(b,p); midx += d
                _,p=uleb(b,p); code,p=uleb(b,p)
                scan_method(midx,code)

            midx=0
            for _ in range(vm):
                d,p=uleb(b,p); midx += d
                _,p=uleb(b,p); code,p=uleb(b,p)
                scan_method(midx,code)
        except Exception:
            continue

for p in sys.argv[1:]:
    scan(p)
