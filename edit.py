# this code looks terrible to a python programmer, but is designed to be easy to
# port to 6502 assembly, so it inherits some of the quirks of that processor.

import sys

before = ""
after  = "\n"

scroll = 0

m_cmd    = 0
m_insert = 1
mode     = 0

newlines = 0 # can be undefined in the asm
scroll_count = 0 # can be undefined in the asm
ch = ""  # can be undefined in the asm

ROWS = 30

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

def draw_header() -> None:
    print("\033[7m", end="")
    print("                           **** OZDOS EDIT V0.0.0 ****                          ")
    
    if mode == m_cmd:
        print("                               --- normal mode ---                              \n")
    elif mode == m_insert:
        print("                               --- insert mode ---                              \n")
    print("\033[0m", end="")
    

def print_char() -> None:
    global scroll_count
    global newlines
    
    if ch == "\n" and scroll_count != 0:
        scroll_count -= 1
        return
    if scroll_count != 0:
        return
    if ch == "\n":
        newlines += 1
    print(ch, end="")

def print_cursor() -> None:
    global scroll_count
    global newlines
    
    if after[0] == "\n":
        newlines += 1
        if scroll_count != 0: scroll_count -= 1
        print("█")
        return

    print("\033[7m", end="")
    print(after[0], end="")
    print("\033[0m", end="")

def draw() -> None:
    global ch
    global scroll_count
    global newlines
    
    print("\033[2J\033[H")
    
    draw_header()
    
    scroll_count = scroll
    newlines = 0
    
    for c in before:
        ch = c
        if ch == "\n" and newlines > ROWS:
            break
        print_char()
        
    print_cursor()
    
    for c in after[1:]:
        ch = c
        if ch == "\n" and newlines > ROWS:
            break
        print_char()

def key_cmd() -> None:
    global before
    global after
    global scroll
    global mode
    
    key = chr(0x00)
    while key == chr(0x00):
        key = getch()
    
    if key == "J":
        scroll += 1
        return
    if key == "K":
        if scroll == 0: return
        scroll -= 1
        return
    
    if key == "h":
        if len(before) == 0: return
        after = before[-1] + after
        before = before[:-1]
        return
    if key == "l":
        if len(after) == 1: return
        before = before + after[0]
        after = after[1:]
        return
    
    if key == "q":
        print("\033[?25h")
        exit(0)
    
    if key == "i":
        mode = m_insert
        return

def key_insert() -> None:
    global before
    global after
    global mode
    
    key = chr(0x00)
    while key == chr(0x00):
        key = getch()
        
    if key == "\033":
        mode = m_cmd
        return
    
    if key == "\b" or key == "\x7f":
        before = before[:-1]
        return
        
    before += key

def handle_key() -> None:
    if mode == m_cmd:
        key_cmd()
        return
    key_insert()

def main() -> None:
    print("\033[?25l")
    
    while True:
        draw()
        handle_key()

if __name__ == "__main__":
    with open("disks/devkit/monitor.asm", "r") as f:
        before = f.read()
        scroll = len(before.split("\n")) - ROWS
        
    main()
