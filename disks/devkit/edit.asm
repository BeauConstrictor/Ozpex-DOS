  .org $0400

; ---------- ;
; memory map ;
; ---------- ;
SERIAL      = $8002

; ------------ ;
; system calls ;
; ------------ ;
print       = $ff0c

; ----------------- ;
; memory allocation ;
; ----------------- ;
PRINT       =   $05  ; 2 B

mode        =   $40  ; 1 B ; 0 for normal, 1 for insert
scroll      =   $41  ; 2 B
before      = $2400  ; shared with after to the end of memory
after       = $7ffd  ; range from before -> after (gap buffer)
before_end  = $23fe  ; 2 B
after_begin = $7ffe  ; 2 B

; --------- ;
; constants ;
; --------- ;
ROWS     =  40
M_CMD    =   0
M_INSERT =   1

CLEAR    = $11

main:
  ; initialise variables
  lda #0
  sta mode
  sta scroll
  ; TODO: intitialise before and after

  ; turn off the terminal's cursor (edit uses a custom one)
  lda #>cursor_off
  sta PRINT+1
  lda #cursor_off
  sta PRINT
  jsr print

mainloop:
  jsr draw
  jsr handle_key
  jmp mainloop

draw:
  lda #CLEAR
  sta SERIAL

  lda mode
  ; because M_CMD = 0, we don't need a cmp
  bne _draw_not_normal
  lda #>normal_msg
  sta PRINT+1
  lda #normal_msg
  sta PRINT
  jsr print
_draw_not_normal:

  cmp #M_INSERT
  bne _draw_not_insert
  lda #>insert_msg
  sta PRINT+1
  lda #insert_msg
  sta PRINT
  jsr print
_draw_not_insert:

  rts

handle_key:
  lda SERIAL
  beq handle_key
  rts

normal_msg:
  .byte "--- normal mode ---\n\n", 0
insert_msg:
  .byte "--- insert mode ---\n\n", 0

cursor_off:
  .byte "\033[?25l", 0
cursor_on:
  .byte "\033[?25h", 0