  .org $c003

SERIAL = $8002
DISKA  = $8003
DISKB  = $a003

; memory allocation:
prgload = $5fff ; 8 KiB, right up to the end of RAM

reset:
  jmp reset

  .org $fffc
  .word reset
