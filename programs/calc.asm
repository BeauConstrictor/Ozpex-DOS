  .org $0400

SERIAL  = $8002
NEWLINE =    $a
ESCAPE  =   $1b
CLEAR   =   $11

EXIT_VEC = $fff8

; memory allocation:
PRINT      = $50      ; 2 bytes
BYTE_BUILD = $40      ; 1 byte
OPERANDA   = $30      ; 1 byte
OPERATOR   = $20      ; 1 byte
OPERANDB   = $10      ; 1 byte

loop:
  jsr expression
  jmp loop

; calculate an addition or subtraction, taking input and printing output
expression:
  ; get the first number and store it in memory
  jsr get_byte
  sta OPERANDA
  
  ; get the operation type, used later
  jsr get_key
  sta OPERATOR

  ; get the second number
  jsr get_byte
  sta OPERANDB

  ; print ' = '
  lda #equals
  sta PRINT
  lda #>equals
  sta PRINT+1
  jsr print

  ; if they chose addition, skip the next section
  lda OPERATOR
  cmp #"+"
  beq _expression_addition

  ; find the result with subtraction
  lda OPERANDA
  sec
  sbc OPERANDB
  jmp _expression_print
_expression_addition:
  ; add the numbers
  lda OPERANDA
  clc
  adc OPERANDB
_expression_print:
  ; print the result
  jsr hex_byte
  stx SERIAL
  sty SERIAL

  ; return back to the system monitor
  lda #NEWLINE
  sta SERIAL
  rts

; return (in a) a single key, ignoring spaces
; modifies: a (duh)
get_key:
  lda SERIAL
  beq get_key       ; if no char was typed, check again.
  cmp #ESCAPE       ; if escape was pressed,
  beq _get_key_exit ; return to the system monitor
  sta SERIAL        ; echo back the char.
  cmp #" "          ; if space was pressed,
  beq get_key       ; wait for the next key.
  rts
_get_key_exit:
  lda #NEWLINE
  sta SERIAL
  jmp (EXIT_VEC)

; wait for a key and return (in a) the value of a single hex char
; modifies: a (duh)
get_nibble:
  jsr get_key
  cmp #$3a
  bcc _get_nibble_digit
  sec
  sbc #"a" - 10
  rts
_get_nibble_digit:
  sbc #"0" - 1
  rts

; return (in a) the a register as hex
; modifies: a (duh)
hex_nibble:
  cmp #10
  bcc _hex_nibble_digit
  clc
  adc #"a" - 10
  rts
_hex_nibble_digit:
  adc #"0"
  rts

; return (in x & y) the a register as hex
; modifies: x, y, a
hex_byte:
  pha ; save the full value for later
  ; get just the MSN
  lsr
  lsr
  lsr
  lsr
  jsr hex_nibble
  tax ; but the hex char for the MSN in x

  pla ; bring back the full value
  and #$0f ; get just the LSN
  jsr hex_nibble
  tay ; but the hex char for the LSN in y

  rts

; wait for a key and return (in a) the value of a byte (2 hex chars)
; modifies: a (duh)
get_byte:
  ; get the MS nibble and move it to the MS area of the a reg
  jsr get_nibble
  asl
  asl
  asl
  asl
  ; move the MSN to memory
  sta BYTE_BUILD

  ; get the LSN and combine it with the MSN
  jsr get_nibble
  ora BYTE_BUILD
  rts

; print a null-terminated string pointed to by PRINT
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

equals:
  .byte " = ", 0