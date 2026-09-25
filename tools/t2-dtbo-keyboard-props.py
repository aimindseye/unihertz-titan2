#!/usr/bin/env python3
import re, struct, sys
from pathlib import Path

if len(sys.argv) != 2:
    print(f'usage: {sys.argv[0]} dtbo.img', file=sys.stderr)
    raise SystemExit(2)

data = Path(sys.argv[1]).read_bytes()
DTBO_MAGIC = 0xD7B7AB1E
FDT_MAGIC = 0xD00DFEED

def u32(buf, off, endian='>'):
    return struct.unpack_from(endian + 'I', buf, off)[0]

endian = next((e for e in ('>', '<') if len(data) >= 32 and u32(data, 0, e) == DTBO_MAGIC), None)
if endian is None:
    print('not an Android DTBO table image', file=sys.stderr)
    raise SystemExit(1)

magic,total,header_size,entry_size,count,entries_off,page_size,version = struct.unpack_from(endian+'8I', data, 0)
print(f'DTBO header: total={total} entry_size={entry_size} entries={count} version={version}')

wanted = re.compile(r'aw9523|keypad_led|mt6363|keyboard|key|wakeup|brightness|pwm|touchpad|synaptics|hynitron', re.I)
BEGIN_NODE, END_NODE, PROP, NOP, END = 1, 2, 3, 4, 9

def align4(n): return (n + 3) & ~3

def fmt(v):
    if not v:
        return '<present>'
    parts = v.rstrip(b'\0').split(b'\0')
    if parts and all(p and all(32 <= b < 127 for b in p) for p in parts):
        return 'strings=' + '|'.join(p.decode('ascii','replace') for p in parts)
    if len(v) % 4 == 0 and len(v) <= 64:
        vals = [struct.unpack_from('>I', v, i)[0] for i in range(0, len(v), 4)]
        return 'u32=' + ','.join(f'{x} (0x{x:x})' for x in vals) + ' hex=' + v.hex()
    return 'hex=' + v.hex()

def parse_fdt(blob, idx):
    if len(blob) < 40 or u32(blob,0,'>') != FDT_MAGIC:
        return
    hdr = struct.unpack_from('>10I', blob, 0)
    _,tot,off_struct,off_strings,_,ver,_,_,size_strings,size_struct = hdr
    strings = blob[off_strings:off_strings+size_strings]
    pos, endpos, stack = off_struct, min(len(blob), off_struct+size_struct), []
    print(f'ENTRY {idx}: fdt_size={tot} version={ver}')
    while pos + 4 <= endpos:
        tok = u32(blob,pos,'>'); pos += 4
        if tok == BEGIN_NODE:
            z = blob.find(b'\0', pos, endpos)
            if z < 0: break
            stack.append(blob[pos:z].decode('utf-8','replace'))
            pos = align4(z+1)
        elif tok == END_NODE:
            if stack: stack.pop()
        elif tok == PROP:
            if pos + 8 > endpos: break
            ln,nameoff = struct.unpack_from('>II',blob,pos); pos += 8
            val = blob[pos:pos+ln]; pos = align4(pos+ln)
            z = strings.find(b'\0', nameoff)
            if z < 0: continue
            name = strings[nameoff:z].decode('utf-8','replace')
            path = '/' + '/'.join(x for x in stack if x)
            if wanted.search(path) or wanted.search(name):
                print(f'  {path}:{name} = {fmt(val)}')
        elif tok == NOP:
            pass
        elif tok == END:
            break
        else:
            break

for i in range(count):
    off = entries_off + i*entry_size
    if off + 32 > len(data): break
    size,blob_off,ident,rev,c0,c1,c2,c3 = struct.unpack_from(endian+'8I', data, off)
    parse_fdt(data[blob_off:blob_off+size], i)
