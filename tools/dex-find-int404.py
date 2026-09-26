#!/usr/bin/env python3
import struct, sys
from pathlib import Path

def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u32(b,o): return struct.unpack_from("<I",b,o)[0]

def uleb(b, off):
    val=0; shift=0
    for i in range(5):
        x=b[off]; off+=1
        val |= (x & 0x7f) << shift
        if not (x & 0x80):
            return val, off
        shift += 7
    return val, off

def read_mutf8(b, off):
    _, off = uleb(b, off)
    end = b.find(b"\0", off)
    if end < 0: end = len(b)
    return b[off:end].decode("utf-8","replace")

def signed16(x): return x-0x10000 if x & 0x8000 else x
def signed32(x): return x-0x100000000 if x & 0x80000000 else x

def scan(path):
    b=Path(path).read_bytes()
    if b[:3] != b"dex":
        print(f"{path}: not dex")
        return
    string_ids_size=u32(b,0x38); string_ids_off=u32(b,0x3c)
    type_ids_size=u32(b,0x40); type_ids_off=u32(b,0x44)
    method_ids_size=u32(b,0x58); method_ids_off=u32(b,0x5c)
    class_defs_size=u32(b,0x60); class_defs_off=u32(b,0x64)

    strings=[read_mutf8(b,u32(b,string_ids_off+4*i)) for i in range(string_ids_size)]
    types=[strings[u32(b,type_ids_off+4*i)] for i in range(type_ids_size)]
    methods=[]
    for i in range(method_ids_size):
        off=method_ids_off+8*i
        class_idx, proto_idx, name_idx = struct.unpack_from("<HHI",b,off)
        methods.append((types[class_idx] if class_idx < len(types) else f"type#{class_idx}",
                        strings[name_idx] if name_idx < len(strings) else f"str#{name_idx}"))

    hits=[]
    for ci in range(class_defs_size):
        off=class_defs_off+32*ci
        class_data_off=u32(b,off+24)
        if not class_data_off: continue
        p=class_data_off
        try:
            sf,p=uleb(b,p); inf,p=uleb(b,p); dm,p=uleb(b,p); vm,p=uleb(b,p)
            for _ in range(sf+inf):
                _,p=uleb(b,p); _,p=uleb(b,p)
            midx=0
            for _ in range(dm+vm):
                diff,p=uleb(b,p); midx += diff
                _,p=uleb(b,p); code_off,p=uleb(b,p)
                if not code_off or code_off+16 > len(b): continue
                insns_size=u32(b,code_off+12)
                insn_off=code_off+16
                end=min(len(b), insn_off+2*insns_size)
                units=[u16(b,i) for i in range(insn_off,end,2)]
                reasons=[]
                j=0
                while j < len(units):
                    op=units[j] & 0xff
                    if op == 0x13 and j+1 < len(units) and signed16(units[j+1]) == 404:
                        reasons.append(f"const/16@{j}")
                    elif op == 0x14 and j+2 < len(units):
                        lit=signed32(units[j+1] | (units[j+2]<<16))
                        if lit == 404: reasons.append(f"const@{j}")
                    if units[j] == 0x0100 and j+3 < len(units):
                        sz=units[j+1]
                        first=signed32(units[j+2] | (units[j+3]<<16))
                        if first <= 404 < first+sz:
                            reasons.append(f"packed-switch-key@{j}")
                    elif units[j] == 0x0200 and j+1 < len(units):
                        sz=units[j+1]
                        for k in range(sz):
                            q=j+2+2*k
                            if q+1 >= len(units): break
                            key=signed32(units[q] | (units[q+1]<<16))
                            if key == 404:
                                reasons.append(f"sparse-switch-key@{j}")
                                break
                    j += 1
                if reasons and midx < len(methods):
                    cls,name=methods[midx]
                    hits.append((cls,name,",".join(sorted(set(reasons)))))
        except Exception:
            continue
    for cls,name,why in hits:
        print(f"{path}\t{cls}->{name}\t{why}")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        scan(p)
