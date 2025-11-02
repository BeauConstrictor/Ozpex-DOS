# build an Ozpex DOS filesystem

img = bytearray(8192)

files = [
    ["test        txt", 3],
    ["hello-world img", 4],
]

data_sectors = [ # starting at 3
    ["Hello World!", 0x00, True],
    ["\x60",         0x00, True],
]

# sectors 0 & 1 - filename mapping
idx = 0
for f in files:
    for i, ch in enumerate(f[0]):
        img[idx+i] = ord(ch)
    img[idx+15] = f[1]
    idx += 16
    
    
# sector 2 - sector usage info
img[0x0200] = 0xff # sector 0 is always occupied
img[0x0201] = 0xff # sector 1 is always occupied
img[0x0202] = 0xff # sector 2 is always occupied

for i, _ in enumerate(data_sectors, start=3):
    img[0x0200 + i] = 0xff

# sector 2 - filesystem signature / magic number
img[0x02fc] = 0xde
img[0x02fd] = 0xad
img[0x02fe] = 0xbe
img[0x02ff] = 0xef

# sectors 3... - main data
for i, s in enumerate(data_sectors):
    addr = (i+3) * 0x100
    info_byte = s[1] | (0x80 if s[2] else 0x00)
    for idx, byte in enumerate(s[0]):
        img[addr + idx] = ord(byte)
    img[addr+0xff] = info_byte

with open("../ozpex-64/bbrams/o64dos-fs.bin", "wb") as file:
    file.write(img)
