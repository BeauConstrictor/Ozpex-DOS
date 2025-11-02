  .org $c003

DELETE    = $7f
CLEAR     = $11

; ---------- ;
; memory map ;
; ---------- ;
SERIAL = $8002
DISKA  = $8003
DISKB  = $a003

; ----------------- ;
; memory allocation ;
; ----------------- ;
disk         =   $00  ;   1 B;  0 for A and other for B
addr         =   $01  ;   2 B;  general purpose word for subroutines
byte         =   $03  ;   1 B;  general purpose byte for subroutines
PRINT        =   $04  ;   2 B 
cmd_handler  =   $08  ;   2 B
cmd_buf      =   $10  ;   2 B
input_buf    = $0200  ; 256 B;  null-terminated
input_ptr    = $01ff  ;   1 B;  where parsing commands should read from
prgload      = $5fff  ; 8 KiB;  right up to the end of RAM

reset:
  ; start on disk A
  lda #00
  sta disk

  lda #welcome_msg
  sta PRINT
  lda #>welcome_msg
  sta PRINT+1
  jsr print

mainloop:
  jsr run_command
  jmp mainloop

done:
  jmp done

; ------------------- ;
; filesystem routines ;
; ------------------- ;

; output the address of the current disk in adddr
; modifies: a
get_disk:
  lda disk                   ; check which disk is active
  bne _get_sector_not_disk_a ; if it's b, handle that
  lda #DISKA                 ; otherwise, load disk a's addr
  sta addr                   ; ^
  lda #>DISKA                ; ^
  sta addr+1                 ; ^
  rts                        ; then return
_get_sector_not_disk_a:
  lda #DISKB                 ; load disk b's addr
  sta addr                   ; ^
  lda #>DISKB                ; ^
  sta addr+1                 ; ^
  rts                        ; return

; return the address of a certain sector (from A) on the current disk into addr
; expects: addr to hold the address of the current disk
; modifies: a
get_sector:
  sta byte   ; put the sector id in memory
  lda addr+1 ; get the high byte of the current disk
  clc        ; always do this before addition
  adc byte   ; move to the correct sector
  sta addr+1 ; store the full address of the new sector
  rts        ; return

; output the name and extension of the file entry
; expects addr to address the first byte of a file entry from sector 0 or 1
; modifies: a, y
print_file:
  ldy #00
_print_file_loop_name:
  ; loop over the 12 char file name
  lda (addr),y
  beq _print_file_done ; if the entry contains nulls, the file does not exist
  sta SERIAL
_print_file_loop:
  iny
  cpy #12
  bne _print_file_loop_name
  ; start printing the extension
  lda #"."
  sta SERIAL
_print_file_loop_ext:
  ; loop over the 3 char extension
  lda (addr),y
  sta SERIAL
  iny
  cpy #15
  bne _print_file_loop_ext
  lda #"\n"
  sta SERIAL
_print_file_done:
  rts

; ---------- ;
; user input ;
; ---------- ;

; run a full command, (re-enters the mainloop on error)
run_command:
  jsr show_prompt

  jsr get_line
  ldx #0                  ; start checking at the first opcode in the table
  jsr expect_key
  sta cmd_buf
  jsr expect_key
  sta cmd_buf+1
  jsr expect_key
  sta cmd_buf+2
dispatch_loop:
  jsr dispatch            ; run the opcode handler if it matches and move on
  cpy #1                  ; if a match was not found,
  bne dispatch_loop       ; keep going.
  cpx #249              ; if the table is exhausted,
  bcs _dispatch_loop_fail ; the opcode is unknown. 
  rts
_dispatch_loop_fail:
  jmp bad_handler

; show the user's disk, prompting for input
; modifies: a
show_prompt:
  lda disk
  bne _show_prompt_not_a
  lda #"A"
  sta SERIAL
  jmp _show_prompt_not_b
_show_prompt_not_a:
  lda #"A"
  sta SERIAL
_show_prompt_not_b:
  lda #">"
  sta SERIAL
  lda #" "
  sta SERIAL
  rts

; buffer a line of input, null-terminated.
get_line:
  ldx #0
  stx input_ptr
_get_line_loop:
  lda SERIAL
  beq _get_line_loop      ; if no key pressed, check again

  cmp #DELETE             ; if backspace pressed, remove last char
  beq _get_line_backspace
  cmp #"\b"               ; either of these codes may be emitted for a backspace
  beq _get_line_backspace

  cmp #"\n"               ; if enter pressed, write a null and exit
  beq _get_line_done

  sta SERIAL              ; echo back the char

  sta input_buf,x         ; write the char to the input buffer
  inx
  jmp _get_line_loop
_get_line_done:
  sta SERIAL
  lda #0
  sta input_buf,x
  rts
_get_line_backspace:
  lda #"\b"
  sta SERIAL
  lda #" "
  sta SERIAL
  lda #"\b"
  sta SERIAL
  dex
_get_line_backspace_ignore:
  jmp _get_line_loop

; expect from the input buffer and return (in a) a single key, ignoring spaces
; modifies: a, x, y
expect_key:
  ldx input_ptr
  inc input_ptr        ; move the buf ptr to the next char for the next call to get_Key
  lda input_buf,x      ; read the key from the buf
  beq _expect_key_fail ; if the input buffer is exhausted, throw error
  cmp #" "             ; if space was pressed,
  beq expect_key       ; skip the key.
  rts
_expect_key_fail:
  jmp bad_handler

; 1. match the xth element in the opcode table with the input buffer
; 2. if it matches, call the opcode handler
; 3. increment x by 5
; 4. return in y 1 if the opcode matched, otherwise 0
dispatch:
  lda cmd_map,x
  cmp cmd_buf
  bne _dispatch_miss_1
  inx
  lda cmd_map,x
  cmp cmd_buf+1
  bne _dispatch_miss_2
  inx
  lda cmd_map,x
  cmp cmd_buf+2
  bne _dispatch_miss_3
  inx

  lda cmd_map,x
  sta cmd_handler
  lda cmd_map+1,x
  sta cmd_handler+1

  jsr get_disk
  ; there is no indirect jsr, so we do this
  jsr _dispatch_run
  ldy #1
  rts
_dispatch_run:
  jmp (cmd_handler)

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

; -------------- ;
; shell commands ;
; -------------- ;

cmd_map:
  .byte "lst"
  .word  lst
  .byte "usg"
  .word  usg

; list the files in the current disk out to the serial port
; expects: addr to hold the address of the current disk
; modifies: a, x, y
lst:
  ldx #32
_list_loop:
  jsr print_file
  lda addr
  clc
  adc #16
  sta addr
  bcc _list_didnt_carry
  inc addr+1
_list_didnt_carry:
  dex
  bne _list_loop
  rts

usg:
  lda #02           ; go to sector two (usage info)
  jsr get_sector    ; ^
  ldx #00           ; start disk usage at zero
  ldy #00           ; start reading usage info for sector 0
_usg_loop:
  lda (addr),y      ; check the usage for the sector
  beq _usg_not_used ; if the sector is not used, don't count it
  inx               ; if its used, count it
_usg_not_used:
  iny               ; move to the next sector
  cpy #32           ; check if we have read all the sectors
  bne _usg_loop     ; loop again
  txa
  jsr hex_byte      ; print the usage info
  stx SERIAL
  sty SERIAL
  lda #"/"          ; show that it is out of $20 (32 decimal)
  sta SERIAL
  lda #"2"
  sta SERIAL
  lda #"0"
  sta SERIAL
  lda #"\n"
  sta SERIAL
  rts

; ---------------- ;
; misc subroutines ;
; ---------------- ;

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

; its easy to just jump here if there is an error
bad_handler:
  lda #err_msg
  sta PRINT
  lda #>err_msg
  sta PRINT+1
  jsr print
  jmp mainloop

; -------- ;
; messages ;
; -------- ;

err_msg:
  .byte "\n"
  .byte ">:("
  .byte "\n"
  .byte 0

welcome_msg:
  .byte CLEAR
  .byte "**** Ozpex DOS v0.1.0 ****\n"
  .byte "Disk A ready.\n\n"
  .byte 0

  .org $fffc
  .word reset
