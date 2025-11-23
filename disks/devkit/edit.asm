  .org $0300

; ----- memory map ----- ;
SERIAL             = $8002
EXIT               = $fff8  
bufstart           = $3000
bufend             = $7fff
; ---------------------- ;

; ------ syscalls ------ ;
print              = $ff0c
; ---------------------- ;

; ----- allocation ----- ;
PRINT          = $05 ; 2 B

scroll         = $40 ; 2 B

mode           = $42 ; 1 B

newlines       = $43 ; 2 B
scroll_count   = $45 ; 2 B
ch             = $47 ; 1 B

gapstart       = $48 ; 2 B
aftergap       = $4a ; 2 B

bufidx         = $4c ; 2 B
; ---------------------- ;


; ------- consts ------- ;
CLEAR                = $11

NORMAL               =   0
INSERT               =   1
ROWS                 =  30

DELETE               = 127
; ---------------------- ;

main:
  ; before = ""
  lda #>bufstart
  sta gapstart+1
  lda #<bufstart
  sta gapstart

  ; after = "\n"
  lda #>$7fff
  sta aftergap+1
  lda #<$7fff
  sta aftergap
  lda #"\n"
  sta $7fff

  lda #0
  ; scroll = 0
  sta scroll
  ; mode = 0
  sta mode

  ; disable terminal cursor
  lda #>cursor_off
  sta PRINT+1
  lda #<cursor_off
  sta PRINT
  jsr print
mainloop:
  jsr draw
  jsr handle_key
  jsr mainloop

handle_key:
  lda SERIAL
  beq handle_key

  ldx mode
  cpx #NORMAL
  bne key_insert
  jmp key_normal
  rts

; expects the last key that was pressed to be in a
key_insert:
  cmp #"\e"
  beq _key_insert_esc
  cmp #"\b"
  beq _key_insert_backspace
  cmp #DELETE
  beq _key_insert_backspace ; some terminals will send this instead

  ldy #0
  sta (gapstart),y
  inc gapstart
  bne _key_insert_done
  inc gapstart+1
_key_insert_done:
  rts
_key_insert_esc
  lda #NORMAL
  sta mode
  rts
_key_insert_backspace:
  lda gapstart
  bne _key_insert_backspace_no_carry
  dec gapstart
_key_insert_backspace_no_carry:
  dec gapstart
  rts

; expects the last key that was pressed to be in a
key_normal:
  cmp #"q"
  beq _key_normal_q
  cmp #"i"
  beq _key_normal_i
  cmp #"l"
  beq _key_normal_l
  cmp #"h"
  beq _key_normal_h
  rts
_key_normal_q:
  lda #"\n"
  sta SERIAL
  sta SERIAL
  lda #>show_cursor
  sta PRINT+1
  lda #<show_cursor
  sta PRINT
  jsr print
  jmp (EXIT)
_key_normal_i:
  lda #INSERT
  sta mode
  rts
_key_normal_l:
  ldy #0
  lda (aftergap),y
  sta (gapstart),y
  inc gapstart
  bne _key_normal_gapstart_no_carry
  inc gapstart+1
_key_normal_gapstart_no_carry:
  inc aftergap
  bne _key_normal_l_aftergap_no_carry
  inc aftergap+1
_key_normal_l_aftergap_no_carry:
  rts
_key_normal_h:
  ldy #$ff
  dec gapstart+1
  lda (gapstart),y
  inc gapstart+1
  dec aftergap+1
  sta (aftergap),y
  inc aftergap+1

  dec aftergap
  lda aftergap
  cmp #$ff
  bne _key_normal_h_aftergap_no_carry
  dec aftergap+1
_key_normal_h_aftergap_no_carry:
  dec gapstart
  lda gapstart
  cmp #$ff
  bne _key_normal_h_gapstart_no_carry
  dec gapstart+1
_key_normal_h_gapstart_no_carry:
  rts  

draw_header:
  lda #>header
  sta PRINT+1
  lda #<header
  sta PRINT
  jsr print

  lda mode
  bne draw_header_not_normal_mode
  lda #>normal_mode_header
  sta PRINT+1
  lda #<normal_mode_header
  sta PRINT
  jsr print
  jmp _draw_header_is_normal_mode
draw_header_not_normal_mode:
  lda #>insert_mode_header
  sta PRINT+1
  lda #<insert_mode_header
  sta PRINT
  jsr print
_draw_header_is_normal_mode:

  lda #>restore_video
  sta PRINT+1
  lda #<restore_video
  sta PRINT
  jsr print
  rts

draw_cursor:
  ; reverse the text colours
  lda #>reverse_video
  sta PRINT+1
  lda #<reverse_video
  sta PRINT
  jsr print
  ; read the character after the cursor
  ldy #0
  lda (aftergap),y
  cmp #"\n"
  bne _draw_cursor_not_newline
  lda #" "
  sta SERIAL
  jmp _draw_cursor_done
_draw_cursor_not_newline:
  ; print the character after the cursor (with the reversed colours)
  sta SERIAL
_draw_cursor_done:
  ; go back to normal colours again
  lda #>restore_video
  sta PRINT+1
  lda #<restore_video
  sta PRINT
  jsr print
  rts

draw:
  lda #CLEAR
  sta SERIAL

  jsr draw_header

  ; scroll_count = scroll
  lda #scroll
  sta scroll_count
  ; newlines = 0
  lda #0
  sta newlines

  ; if the first character in the gap is the start of the buffer, then we
  ; shouldn't draw anything
  lda gapstart+1
  cmp #>bufstart
  bne _draw_before_loop_do
  lda gapstart
  cmp #<bufstart
  bne _draw_before_loop_do
  jmp _draw_before_loop_skip
_draw_before_loop_do:
  lda #>bufstart
  sta bufidx+1
  lda #<bufstart
  sta bufidx
  ldy #0
_draw_before_loop:
  lda (bufidx),y
  sta ch
  sta SERIAL
  jsr inc_bufidx
  ; check if we are now at the start of the gap
  lda gapstart+1
  cmp bufidx+1
  bne _draw_before_loop
  lda gapstart
  cmp bufidx
  bne _draw_before_loop
_draw_before_loop_skip:

  ; in between the text before the cursor and the text after the cursor
  jsr draw_cursor

  lda aftergap+1
  cmp #>bufend
  bne _draw_after_loop_do
  lda aftergap
  cmp #<bufend
  bne _draw_after_loop_do
  jmp _draw_after_loop_skip
_draw_after_loop_do:
  lda #>aftergap
  sta bufidx+1
  lda #<aftergap
  sta bufidx
  ldy #0
_draw_after_loop:
  lda (bufidx),y
  sta ch
  sta SERIAL
  jsr inc_bufidx
  ; check if we are now at the start of the gap
  lda aftergap+1
  cmp bufidx+1
  bne _draw_after_loop
  lda aftergap
  cmp bufidx
  bne _draw_after_loop
_draw_after_loop_skip:

  ; check if we reached the end of the buffer
  lda bufidx+1
  cmp #>bufend
  bne _draw_after_loop_not_done
  lda bufidx
  cmp #<bufend
  beq _draw_after_loop_done
_draw_after_loop_not_done:
  jmp _draw_after_loop
_draw_after_loop_done:
  rts

inc_bufidx:
  inc bufidx
  bne _inc_bufidx_no_carry
  inc bufidx+1
_inc_bufidx_no_carry:
  rts


cursor_off:
  .byte "\e[?25l", 0

header:
  .byte "\e[7m                           **** OZDOS EDIT V0.0.0 ****                          \n", 0
reverse_video:
  .byte "\e[7m", 0 ; i know this is duplication, but actually results in less
                   ; bytes than two print calls when drawing the header
restore_video:
  .byte "\e[0m", 0

show_cursor:
  .byte "\e[?25h", 0

normal_mode_header:
  .byte "                               --- normal mode ---                              \n\n", 0
insert_mode_header:
  .byte "                               --- insert mode ---                              \n\n", 0
