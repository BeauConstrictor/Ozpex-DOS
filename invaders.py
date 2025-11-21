import sys
import time

blocks = [int(i) for i in "1100011001100011"]

player_x = 7

enemies = [0b1010101010101010 for i in range(6)]

iteration = 0

if sys.platform.startswith("win"):
    import msvcrt

    def getch() -> str:
        if msvcrt.kbhit():
            c = msvcrt.getwch()
            if c == '\r': c = '\n'
            return c
        return chr(0)

else:
    import select
    import tty
    import termios

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    tty.setcbreak(fd)

    def getch() -> str:
        dr, dw, de = select.select([sys.stdin], [], [], 0)
        if dr:
            return sys.stdin.read(1)
        return chr(0)

    import atexit
    
    atexit.register(lambda: termios.tcsetattr(fd, termios.TCSADRAIN, old_settings))

def draw() -> None:
    print("\033[2J\033[H")
    
    print("-" * 32)
    
    for row in enemies:
        byte = (row >> 8) & 0xff
        for i in range(8):
            if byte & 0b10000000 == 0:
                sys.stdout.write("  ")
            else:
                sys.stdout.write("@ ")
            byte = (byte << 1) & 0xFF
        byte = row & 0xff
        for i in range(8):
            if byte & 0b10000000 == 0:
                sys.stdout.write("  ")
            else:
                sys.stdout.write("@ ")
            byte = (byte << 1) & 0xFF
        sys.stdout.write("\n")
        
    sys.stdout.write("\n\n")
    
    for i in range(16):
        sys.stdout.write("##" if blocks[i] else "  ")
    sys.stdout.write("\n\n")
    
    for i in range(16):
        if i == player_x:
            sys.stdout.write("^^")
        else:
            sys.stdout.write("  ")
    sys.stdout.write("\n")
    
    print("-" * 32)

def step() -> None:
    global enemies
    
    if iteration & 0b1111111 == 0:
        for i in range(len(enemies)):
            enemies[i] >>= 1
            enemies[i] &= 0xffff
            
    if iteration & 0b1111111 == 0b0111111:
        for i in range(len(enemies)):
            enemies[i] <<= 1
            enemies[i] &= 0xffff
            
def handle_key() -> None:
    global player_x
    
    key = getch()
    
    if key == chr(0x00):
        return
        
    if key == "a":
        player_x -= 1
        player_x &= 0xf
        return
    if key == "d":
        player_x += 1
        player_x &= 0xf
        return

def main() -> None:
    global iteration
    while True:
        draw()
        step()
        handle_key()
        time.sleep(0.01)
        iteration += 1

if __name__ == "__main__":
    main()