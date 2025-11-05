  .org $0400

; memory map:
SERIAL   = $8002
EXIT_VEC = $fff8

; ascii codes:
NEWLINE   = $0a
ESCAPE    = $1b
DELETE    = $7f
BACKSPACE = $08

; memory allocation:
BYTE_BUILD  = $40     ; 1 byte
PRINT       = $50     ;  1byte
opc_buf     = $20     ; 3 bytes 
opc_handler = $23     ; 2 bytes
insert_ptr  = $30     ; 2 bytes (matches the monitor)
input_buf   = $0200   ; 256 bytes
input_ptr   = $10     ; 1 bytes
word_build  = $05     ; 2 bytes

main:
  lda #start_msg
  sta PRINT
  lda #>start_msg
  sta PRINT + 1
  jsr print

mainloop:
  lda #NEWLINE
  sta SERIAL
  jsr print_addr
  jsr get_line
  jsr get_key
  sta opc_buf
  jsr get_key
  sta opc_buf+1
  jsr get_key
  sta opc_buf+2

  ldx #0            ; start checking at the first opcode in the table
dispatch_loop:
  jsr dispatch      ; run the opcode handler if it matches and move on
  cpy #1            ; if a match was not found,
  bne dispatch_loop ; keep going.
  cpx #249          ; if the table is exhausted,
  bcs _dispatch_loop_fail   ; the opcode is unknown. 
  jmp mainloop      ; otherwise, read the next opcode
_dispatch_loop_fail:
  jmp bad_handler

; increment the insertion pointer
inc_insert:
  inc insert_ptr
  bne _inc_insert_done
  inc insert_ptr+1
_inc_insert_done:
  rts

; insert the a register and move on
insert_a:
  ldy #0
  sta (insert_ptr),y
  jsr inc_insert
  rts

; insert the x and a registers and move on
insert_ax:
  ldy #0
  pha
  txa
  sta (insert_ptr),y
  jsr inc_insert
  pla
  sta (insert_ptr),y
  jsr inc_insert
  rts

; get a value in hex, and return it in A (TODO: support binary (%) and decimal)
get_val:
  jsr get_key
  cmp #"$"
  bne _get_val_not_hex
  jsr get_byte
  rts
_get_val_not_hex:

  cmp #$22 ; double quote
  bne _get_val_not_char
  jsr get_key
  pha
  jsr get_key
  pla
  rts

_get_val_not_char:
  jmp bad_handler

; get a word in hex and return it in a and x
get_word:
  jsr get_key
  cmp #"$"
  bne _get_word_fail
  jsr get_byte
  pha
  jsr get_byte
  tax
  pla
  rts
_get_word_fail:
  jmp bad_handler

; print the insertion pointer
print_addr:
  lda insert_ptr+1
  jsr hex_byte
  stx SERIAL
  sty SERIAL
  lda insert_ptr
  jsr hex_byte
  stx SERIAL
  sty SERIAL
  lda #":"
  sta SERIAL
  lda #" "
  sta SERIAL
  rts

; 1. match the xth element in the opcode table with the input buffer
; 2. if it matches, call the opcode handler
; 3. increment x by 5
; 4. return in y 1 if the opcode matched, otherwise 0
dispatch:
  lda opcode_table,x
  cmp opc_buf
  bne _dispatch_miss_1
  inx
  lda opcode_table,x
  cmp opc_buf+1
  bne _dispatch_miss_2
  inx
  lda opcode_table,x
  cmp opc_buf+2
  bne _dispatch_miss_3
  inx

  lda opcode_table,x
  sta opc_handler
  lda opcode_table+1,x
  sta opc_handler+1

  ; there is no indirect jsr, so we do this
  jsr _dispatch_run
  ldy #1
  rts
_dispatch_run:
  jmp (opc_handler)

_dispatch_miss_3:
  dex
_dispatch_miss_2:
  dex
_dispatch_miss_1:
  inx
  inx
  inx
  inx
  inx
  ldy #0
  rts

; not a subroutine like the others, you can jump here if you
; encounter an error in parsing
bad_handler:
  lda #err_msg
  sta PRINT
  lda #>err_msg
  sta PRINT+1
  jsr print
  jmp mainloop

; buffer a line of input, null-terminated.
get_line:
  ldx #0
  stx input_ptr
_get_line_loop:
  lda SERIAL
  beq _get_line_loop ; if no key pressed, check again
  
  cmp #NEWLINE ; if enter pressed, write a null and exit
  beq _get_line_done

  cmp #DELETE ; if backspace pressed, remove last char
  beq _get_line_backspace
  cmp #BACKSPACE ; either of these codes may be emitted for a backspace by different terminals
  beq _get_line_backspace

  cmp #ESCAPE
  beq _get_line_escape ; if escape was pressed, immediately exit

  sta input_buf,x ; write the char to the input buffer
  sta SERIAL ; echo back the char
  inx
  jmp _get_line_loop
_get_line_done:
  lda #0
  sta input_buf,x
  rts
_get_line_backspace:
  lda #BACKSPACE
  sta SERIAL
  lda #" "
  sta SERIAL
  lda #BACKSPACE
  sta SERIAL
  dex
_get_line_backspace_ignore:
  jmp _get_line_loop
_get_line_escape:
  lda #end_msg
  sta PRINT
  lda #>end_msg
  sta PRINT + 1
  jsr print
  jmp (EXIT_VEC)

; expect from the input buffer and return (in a) a single key, ignoring spaces
; modifies: a, x, y
get_key:
  ldx input_ptr
  inc input_ptr ; move the buf ptr to the next char for the next call to get_Key
  lda input_buf,x ; read the key from the buf
  beq bad_handler ; if the input buffer is exhausted, throw error
  cmp #"@"     ; if "@" was pressed,
  beq _get_key_new_addr  ; move to a new address.
  cmp #" "     ; if space was pressed,
  beq get_key  ; skip the key.
  rts

_get_key_new_addr:
  jsr get_byte ; expect a 2 byte memory address
  sta insert_ptr+1
  jsr get_byte
  sta insert_ptr ; move to the new address
  lda #NEWLINE ; print a newline, to create a new visual block
  sta SERIAL
  jmp mainloop

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

; write the address of a null-terminated string to PRINT
; modifies: a
print:
  tya
  pha
  ldy #0
_print_loop:
  lda (PRINT),y
  beq _print_done
  sta SERIAL
  iny
  jmp _print_loop
_print_done:
  pla
  tay
  rts

start_msg:
  .byte NEWLINE, NEWLINE
  .byte "(mnemonic mode)"
  .byte 0

end_msg:
  .byte NEWLINE, NEWLINE
  .byte "(normal mode)"
  .byte NEWLINE
  .byte 0

err_msg:
  .byte NEWLINE
  .byte "syntax error. check your new memory address before continuing."
  .byte NEWLINE
  .byte 0

; opcode handlers:
lda_handler:
  ; immediate addressing
  jsr get_key
  cmp #"#"
  bne _lda_not_immediate   ; TODO: add support for other addressing modes
  lda #$a9        ; insert the opcode
  jsr insert_a
  jsr get_val     ; insert the immediate value
  jsr insert_a
  rts
_lda_not_immediate:
  ; absolute addressing
  cmp #"$"
  bne _lda_fail
  lda #$ad
  jsr insert_a
  dec input_ptr
  jsr get_word
  jsr insert_ax
  rts
_lda_fail:
  jmp bad_handler
sta_handler:
  lda #$8d
  jsr insert_a
  jsr get_word
  jsr insert_ax
  rts
stx_handler:
  lda #$8e
  jsr insert_a
  jsr get_word
  jsr insert_ax
  rts
sty_handler:
  lda #$8c
  jsr insert_a
  jsr get_word
  jsr insert_ax
  rts

jsr_handler:
  lda #$20
  jsr insert_a
  jsr get_word
  jsr insert_ax
  rts
rts_handler:
  lda #$60
  jsr insert_a
  rts

tax_handler:
  lda #$aa
  jsr insert_a
  rts
tay_handler:
  lda #$a8
  jsr insert_a
  rts
txa_handler:
  lda #$8a
  jsr insert_a
  rts
tya_handler:
  lda #$98
  jsr insert_a
  rts

tsx_handler:
  lda #$ba
  jsr insert_a
  rts
txs_handler:
  lda #$9a
  jsr insert_a
  rts
pha_handler:
  lda #$48
  jsr insert_a
  rts
php_handler:
  lda #$08
  jsr insert_a
  rts
pla_handler:
  lda #$68
  jsr insert_a
  rts
plp_handler:
  lda #$28
  jsr insert_a
  rts

; note to self: make sure to order these roughly by usage, so that
; dispatching is faster
; note to self: 56 instructions * 5 bytes in 280 bytes! not all instructions will fit.
; luckily, the os does not use interrupts, so the interrupt instructions can go, which
; makes it fit. lucky!
opcode_table:
  .byte "lda"
  .word lda_handler
  .byte "sta"
  .word sta_handler
  .byte "stx"
  .word stx_handler
  .byte "sty"
  .word sty_handler

  .byte "rts"
  .word rts_handler
  .byte "jsr"
  .word jsr_handler

  .byte "tax"
  .word tax_handler
  .byte "tay"
  .word tay_handler
  .byte "txa"
  .word txa_handler
  .byte "tya"
  .word tya_handler

  .byte "tsx"
  .word tsx_handler
  .byte "txs"
  .word txs_handler
  .byte "pha"
  .word pha_handler
  .byte "php"
  .word php_handler
  .byte "pla"
  .word pla_handler
  .byte "plp"
  .word plp_handler
