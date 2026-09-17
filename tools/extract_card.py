import struct, base64, json, sys

p = r'D:\HONOR Share\Honor Share\AQUA _ The Useless Goddess.card.png'
data = open(p, 'rb').read()
print('size:', len(data), 'sig ok:', data[:8] == b'\x89PNG\r\n\x1a\n')

i = 8
chunks = []
while i < len(data):
    ln = struct.unpack('>I', data[i:i+4])[0]
    typ = data[i+4:i+8].decode('latin-1')
    body = data[i+8:i+8+ln]
    chunks.append((typ, ln, body))
    if typ == 'IEND':
        break
    i += 12 + ln

print('=== CHUNKS ===')
for typ, ln, body in chunks:
    extra = ''
    if typ in ('tEXt', 'iTXt', 'zTXt'):
        kw = body.split(b'\x00', 1)[0].decode('latin-1', 'replace')
        extra = f' keyword={kw!r}'
    print(f'{typ:6s} len={ln:8d}{extra}')

print()
for typ, ln, body in chunks:
    if typ == 'tEXt':
        kw, _, val = body.partition(b'\x00')
        kw = kw.decode('latin-1')
        if kw.lower() in ('chara', 'ccv3'):
            print(f'--- {kw} (len={len(val)}) ---')
            try:
                dec = base64.b64decode(val).decode('utf-8')
                print('decoded chars:', len(dec))
                j = json.loads(dec)
                print('=== FIELDS ===')
                for k, v in j.items():
                    s = str(v)
                    print(f'  {k:22s} len={len(s):6d} | {s[:70]}')
                open('card_aqua.json', 'w', encoding='utf-8').write(
                    json.dumps(j, ensure_ascii=False, indent=2))
                print('saved -> card_aqua.json')
            except Exception as e:
                print('decode fail:', e)
                print(val[:200])
