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
PRINT        =   $05  ; 2 B

mode         =   $40  ; 1 B ; 0 for normal, 1 for insert
scroll       =   $41  ; 2 B

before       = $2400  ; shared with after to the end of memory
before_end   = $23fe  ; 2 B
after        = $7ffd  ; range from before -> after (gap buffer)
after_begin  = $7ffe  ; 2 B

newlines     = $43 ; 2 B
scroll_count = $45 ; 2 B
ch           = $47 ; 2 B

iter         = $49 ; 2 B

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
  lda #>prepare_term
  sta PRINT+1
  lda #prepare_term
  sta PRINT
  jsr print


mainloop:
  jsr draw
  jsr handle_key
  jmp mainloop


draw_header:
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

  ldx #0

  rts


inc_iter:
  inc iter
  bne _inc_iter_done
  inc iter+1
_inc_iter_done:
  rts


draw:
  lda #CLEAR
  sta SERIAL

  jsr draw_header

  lda scroll
  sta scroll_count
  lda #0
  sta newlines

  lda #>before
  sta iter+1
  lda #before
  sta iter
  ldy #0
_draw_before_loop:
  lda (iter),y
  cmp #"\n"
  bne _draw_before_loop_not_done
  ldx #newlines
  cmp #ROWS
  bcs _draw_before_loop_done
_draw_before_loop_not_done:
  sta ch
  jsr print_ch
  jsr inc_iter
  jmp _draw_before_loop
_draw_before_loop_done:
  

  rts


handle_key:
  lda SERIAL
  beq handle_key
  rts


normal_msg:
  .byte "--- normal mode ---\n\n", 0
insert_msg:
  .byte "--- insert mode ---\n\n", 0

prepare_term:
  .byte "\033[?25l", 0
restore_term:
  .byte "\033[?25h", 0