  .org $0400

NEWLINE = 10

SERIAL = $8002

; memory allocation:
PRINT = $50        ; 2 bytes

reset:
  ; print(*message1);
  lda #message1
  sta PRINT
  lda #>message1
  sta PRINT + 1
  jsr print

  ; print(*message2);
  lda #message2
  sta PRINT
  lda #>message2
  sta PRINT + 1
  jsr print

  rts

; write the address of a null-terminated string to PRINT
; modifies: a, y
print:
  ldy #0
_print_loop:
  lda (PRINT),y
  beq _print_done
  sta SERIAL
  iny
  jmp _print_loop
_print_done:
  rts

message1:
  .byte "Hello, world!", NEWLINE, 0
message2:
  .byte "Goodbye, world!", NEWLINE, 0
