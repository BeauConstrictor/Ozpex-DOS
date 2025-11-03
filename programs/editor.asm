  .org $8003

SERIAL   = $8002
CLEAR    =   $11
DELETE   =   $7f
NEWLINE  =   $0a
ESCAPE   =   $1b

SLOT2    = $a003
SLOT2END = $c002

; memory allocation:
BUFPTR =   $20        ; 1 byte
BUFFER = $0201        ; 256 bytes

  jsr init
  jsr load_buffer
  jsr redraw
main:
  lda SERIAL
  beq main

  cmp #ESCAPE
  beq escape

  jsr write_char

  ; if a backspace is pressed, redraw the entire screen
  cmp #DELETE
  beq mainloop_redraw

  ; else, just draw the new character
  sta SERIAL

  jmp main

mainloop_redraw:
  jsr redraw
  jmp main

escape:
  jsr save_buffer

  lda #NEWLINE
  sta SERIAL

  rts

; clear & draw the screen contents
; modifies: a, x
redraw:
  lda #CLEAR
  sta SERIAL
  jsr print_message
  jsr print_buffer
  rts

; initialise memory
init:
  lda #0
  sta BUFPTR
  rts

; append the character in the a register to the text buffer
; modifies: x
write_char;
  cmp #DELETE
  beq _write_char_delete

  ldx BUFPTR
  inx
  sta BUFFER,x
  inc BUFPTR
  rts
_write_char_delete:
  ; if the buffer is empty, don't let it wrap
  dec BUFPTR
  cmp #$00
  bne _write_char_delete_done
  inc BUFPTR
_write_char_delete_done:
  rts

; display the contents of the text buffer
; modifies: a, x
print_buffer:
  ; will immediately wrap because of the increment
  ldx #$ff
_print_buffer_loop:
  inx
  lda BUFFER,x
  sta SERIAL

  ; print up to the end of the buffer
  cpx BUFPTR
  bne _print_buffer_loop
  rts

; write the contents of slot to to the text buffer
; modifies: a, x
save_buffer:
  ; will immediately wrap because of the increment
  ldx #$ff
_save_buffer_loop:
  inx

  lda BUFFER,x
  sta SLOT2,x

  lda BUFPTR
  sta SLOT2END

  cpx BUFPTR
  bne _save_buffer_loop
  rts

; write the contents of the text buffer to slot 2
; modifies: a, x
load_buffer:
  lda SLOT2END
  sta BUFPTR

  ; will immediately wrap because of the increment
  ldx #$ff
_load_buffer_loop:
  inx

  lda SLOT2,x
  sta BUFFER,x

  lda BUFPTR
  sta SLOT2END

  cpx BUFPTR
  bne _load_buffer_loop
  rts

; print the title message
; modifies: a, x
print_message:
  ldx #0
_print_loop:
  lda message,x
  beq _print_done
  sta SERIAL
  inx
  jmp _print_loop
_print_done:
  rts

message:
  .byte ESCAPE, "[7m"
  .byte " O64 Editor v1.0.0 "
  .byte ESCAPE, "[0m", NEWLINE
  .byte "TIP: press ESC to save to CS2 and quit.", NEWLINE, NEWLINE, 0