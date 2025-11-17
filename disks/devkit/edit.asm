  .org $0400

; ----- memory map ----- ;
SERIAL             = $8002
EXIT               = $fff8  
bufstart           = $3000
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
  bne _key_insert_not_esc
  lda #NORMAL
  sta mode
  rts
_key_insert_not_esc:
  ldy #0
  sta (gapstart),y
  inc gapstart
  rts

; expects the last key that was pressed to be in a
key_normal:
  cmp #"q"
  bne _key_normal_not_q
  lda #>show_cursor
  sta PRINT+1
  lda #<show_cursor
  sta PRINT
  jsr print
  jmp (EXIT)
_key_normal_not_q:
  cmp #"i"
  bne _key_normal_not_i
  lda #INSERT
  sta mode
  rts
_key_normal_not_i:
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

  ; we have already done a ldy #0
  lda aftergap+1
  sta bufidx+1
  lda aftergap
  sta bufidx
_draw_after_loop:
  lda (bufidx),Y
  sta ch
  lda bufidx+1
  cmp aftergap+1
  bne _draw_after_loop_done
  lda aftergap
  cmp bufidx
  bne _draw_after_loop_done
  jsr inc_bufidx
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
