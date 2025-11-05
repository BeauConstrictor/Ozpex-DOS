cd "../$(dirname "$(readlink -f "$0")")"

python fs.py
vasm -dotdir -Fbin dos.asm -o build/rom.bin -esc

rm a.out