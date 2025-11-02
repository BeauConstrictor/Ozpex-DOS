# output an 8K binary containing a valid ozpex dos filesystem

img = bytearray(8192)

files = [
    ["test        txt", 3],
    ["hello-world img", 4],
]

idx = 0
for f in files:
    for i, ch in enumerate(f[0]):
        img[idx+i] = ord(ch)
    img[idx+15] = f[1]
    idx += 16

with open("../ozpex-64/bbrams/o64dos-fs.bin", "wb") as file:
    file.write(img)
