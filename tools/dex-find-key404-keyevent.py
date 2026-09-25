#!/usr/bin/env python3
import re, struct, sys
from pathlib import Path

def u16(b,o): return struct.unpack_from('<H',b,o)[0]
def u32(b,o): return struct.unpack_from('<I',b,o)[0]
def uleb(b, off):
    v=s=0
    for _ in range(5):
        x=b[off]; off+=1; v |= (x & 0x7f) << s
        if not x & 0x80: return v,off
        s += 7
    return v,off
def mutf(b,off):
    _,off=uleb(b,off); end=b.find(b'\0',off)
    return b[off:(len(b) if end<0 else end)].decode('utf-8','replace')
def s16(x): return x-0x10000 if x&0x8000 else x
def s32(x): return x-0x100000000 if x&0x80000000 else x

current_interest=re.compile(r'KeyEvent|dispatchKey|interceptKey|onKey|keyboard|gesture|swipe|touchpad|input.*key', re.I)
ref_interest=re.compile(r'Landroid/view/KeyEvent;|Landroid/hardware/input/InputManager|Landroid/view/InputDevice;|getKeyCode|getScanCode|dispatchKeyEvent|injectInputEvent|interceptKey|onKeyDown|onKeyUp', re.I)

def scan(path):
    b=Path(path).read_bytes()
    if b[:3] != b'dex': return
    ss,so=u32(b,0x38),u32(b,0x3c); ts,to=u32(b,0x40),u32(b,0x44)
    ms,mo=u32(b,0x58),u32(b,0x5c); cs,co=u32(b,0x60),u32(b,0x64)
    strings=[mutf(b,u32(b,so+4*i)) for i in range(ss)]
    types=[strings[u32(b,to+4*i)] for i in range(ts)]
    methods=[]
    for i in range(ms):
        q=mo+8*i; cidx,pidx,nidx=struct.unpack_from('<HHI',b,q)
        methods.append((types[cidx] if cidx<len(types) else str(cidx), strings[nidx] if nidx<len(strings) else str(nidx)))
    for ci in range(cs):
        q=co+32*ci; cdata=u32(b,q+24)
        if not cdata: continue
        p=cdata
        try:
            sf,p=uleb(b,p); inf,p=uleb(b,p); dm,p=uleb(b,p); vm,p=uleb(b,p)
            for _ in range(sf+inf): _,p=uleb(b,p); _,p=uleb(b,p)
            midx=0
            for _ in range(dm+vm):
                d,p=uleb(b,p); midx+=d; _,p=uleb(b,p); code,p=uleb(b,p)
                if not code or code+16>len(b): continue
                n=u32(b,code+12); start=code+16; end=min(len(b),start+2*n)
                units=[u16(b,x) for x in range(start,end,2)]
                has404=False; refs=[]
                j=0
                while j < len(units):
                    op=units[j]&0xff
                    if op==0x13 and j+1<len(units) and s16(units[j+1])==404: has404=True
                    elif op==0x14 and j+2<len(units) and s32(units[j+1]|units[j+2]<<16)==404: has404=True
                    if 0x6e <= op <= 0x72 or 0x74 <= op <= 0x78:
                        if j+1<len(units):
                            mi=units[j+1]
                            if mi < len(methods): refs.append(methods[mi])
                    j += 1
                if not has404 or midx >= len(methods): continue
                cls,name=methods[midx]
                strict_refs=[(a,b) for a,b in refs if ref_interest.search(a+' '+b)]
                if current_interest.search(cls+' '+name) or strict_refs:
                    reftext='; '.join(a+'->'+b for a,b in strict_refs[:30])
                    print(f'{path}\t{cls}->{name}\trefs={reftext}')
        except Exception:
            continue

for p in sys.argv[1:]: scan(p)