# this code looks terrible to a python programmer, but is designed to be easy to
# port to 6502 assembly, so it inherits some of the quirks of that processor.

import sys

buffer = ["_"] * 8192
buffer_end = len(buffer) # first byte after buffer
gap_start = 0 # index of first byte in the gap
after_gap = 8192 # index of first char after the gap

mode = 0

lines = 0 # uninitialsed # how many lines have been printed by draw

INSERT = 1
NORMAL = 0

ROWS = 25

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

def write(ch: str) -> None:
    if ch == chr(0x11):
        print("\033[2J\033[H", end="", flush=True, file=sys.stderr)
    else:
        print(ch, end="", flush=True, file=sys.stderr)

def draw_cursor() -> None:    
        if after_gap == buffer_end:
            write("█")
            return
        if buffer[after_gap] == "\n":
            write("█")
            write("\n")
            return
        
        print("\033[7m", end="", file=sys.stderr)
        write(buffer[after_gap])
        print("\033[0m", end="", file=sys.stderr)

def draw() -> None:
    global lines
    
    lines = 0
    
    write(chr(0x11))
    
    if mode == NORMAL:
        print("--- normal ---\n", file=sys.stderr)
    if mode == INSERT:
        print("--- insert ---\n", file=sys.stderr)
    
    x = 0
    while True:
        if x == gap_start: break
        if buffer[x] == "\n":
            lines += 1
            if lines == ROWS: return
        write(buffer[x])
        x += 1
    
    draw_cursor()
        
    x = after_gap
    x += 1
    while True:
        if x >= buffer_end: break
        if buffer[x] == "\n":
            lines += 1
            if lines == ROWS: return
        write(buffer[x])
        x += 1

def keypress_normal() -> None:
    global gap_start
    global after_gap
    global mode
    
    ch = chr(0)
    while ch == chr(0):
        ch = getch()
    
    if ch == "l":
        if after_gap == buffer_end: return
        char = buffer[after_gap]
        after_gap += 1
        buffer[gap_start] = char
        gap_start += 1
        return
    if ch == "h":
        if gap_start == 0: return
        gap_start -= 1
        char = buffer[gap_start]
        after_gap -= 1
        buffer[after_gap] = char
        return
    if ch == "q":
        export()
        print("\033[?25h", end="", flush=True, file=sys.stderr)
        exit(0)
        return
    if ch == "i":
        mode = INSERT
        return
        
def keypress_insert() -> None:
    global gap_start
    global mode
    
    ch = chr(0)
    while ch == chr(0):
        ch = getch()
        
    if ch == "\033":
        mode = NORMAL
        return
    
    if ch == chr(0x08):
        keypress_insert_backspace()
        return
    if ch == chr(0x7f):
        keypress_insert_backspace()
        return
    
    buffer[gap_start] = ch
    gap_start += 1

def keypress_insert_backspace() -> None:
    global gap_start
    if gap_start == 0: return
    gap_start -= 1

def keypress() -> None:
    if mode == NORMAL:
        keypress_normal()
        return
    keypress_insert()

def export() -> None:
    x = 0
    while True:
        if x == gap_start: break
        sys.stdout.write(buffer[x])
        x += 1
    
    x = after_gap
    x += 1
    while True:
        if x >= buffer_end: break
        sys.stdout.write(buffer[x])
        x += 1

def main() -> None:
    print("\033[?25l", end="", file=sys.stderr)
    
    while True:
        draw()
        keypress()

if __name__ == "__main__":
    main()