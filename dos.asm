  .org $c003

DELETE    = $7f
CLEAR     = $11

A         = 0
B         = 1
T         = 2

; ---------- ;
; memory map ;
; ---------- ;
SERIAL   = $8002
DISKA    = $8003
DISKB    = $a003
DISKT    = $2400
FILELOAD = $0400

; ----------------- ;
; memory allocation ;
; ----------------- ;
disk         =   $00  ;   1 B;  0 for A, 1 for B and other for T
addr         =   $01  ;   2 B;  general purpose word for subroutines
byte         =   $03  ;   1 B;  general purpose byte for subroutines
PRINT        =   $04  ;   2 B 
cmd_handler  =   $08  ;   2 B
cmd_buf      =   $10  ;   3 B
fileop_ptr   =   $13  ;   2 B;  pointer used for file reads and writes
BYTE_BUILD   =   $15  ;   2 B;  used when reading in hex bytes
filename     =   $17  ;  15 B;  filename after its length has been normalised
fname_left   =   $26  ;   1 B;  how many more chars are needed for a full filename
input_buf    = $0200  ; 256 B;  null-terminated
input_ptr    = $01ff  ;   1 B;  where parsing commands should read from

reset:
  ; start on disk T
  lda #T
  sta disk

  ; format the temp disk
  jsr get_disk
  jsr fmt_disk

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
  cmp #A
  bne _get_sector_not_disk_a ; if it's not a, handle that
  lda #DISKA                 ; otherwise, load disk a's addr
  sta addr                   ; ^
  lda #>DISKA                ; ^
  sta addr+1                 ; ^
  rts                        ; then return
_get_sector_not_disk_a:
  cmp #B
  bne _get_sector_not_disk_b ; if it's not b, handle that (its t)
  lda #DISKB                 ; load disk b's addr
  sta addr                   ; ^
  lda #>DISKB                ; ^
  sta addr+1                 ; ^
  rts                        ; return
_get_sector_not_disk_b:
  lda #DISKT                 ; load disk t's addr
  sta addr                   ; ^
  lda #>DISKT                ; ^
  sta addr+1                 ; ^

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

  lda #delimiter
  sta PRINT
  lda #>delimiter
  sta PRINT+1
  jsr print

  ; print the sector id
  tya
  pha
  txa
  pha
  lda (addr),y
  jsr hex_byte
  stx SERIAL
  sty SERIAL
  pla
  tax
  pla
  tay

  lda #"\n"
  sta SERIAL
_print_file_done:
  rts

; increment the addr ptr
; modifies:
inc_addr:
  inc addr
  bne _inc_addr_no_carry_addr
  inc addr+1
_inc_addr_no_carry_addr:
  rts

; increment the fileop_ptr and addr ptr
; modifies: 
inc_fop_addr:
  inc fileop_ptr
  bne _inc_fop_addr_no_carry_fop
  inc fileop_ptr+1
_inc_fop_addr_no_carry_fop:
  jsr inc_addr
  rts

; take a sector id for the start of a file in a, and the location to write
; the readout to in fileop_ptr. returns the contents starting at fileop_ptr,
; and leaves fileop_ptr as addr of the last byte of the file.
; expects: addr to hold the address of the current disk
; modifies: a, x, y
read_file:
  jsr get_sector
  ldy #0
  ldx #255
_read_file_loop:

  ; copy over a single byte
  lda (addr),y
  sta (fileop_ptr),y

  ; point to the next byte
  jsr inc_fop_addr

  ; loop again
  dex
  bne _read_file_loop

  ; parse the final linked list byte
  ; jsr inc_fop_addr
  lda (addr),y
  sta (fileop_ptr),y
  cmp #$80
  beq _read_file_done
  pha
  jsr get_disk
  pla
  jmp read_file

_read_file_done:
  rts

; format the disk with a blank OZDOS-FS
; expects: addr to hold the address of the disk to format
; modifies: a, x, y
fmt_disk:
    lda #$00 ; initialise with zeros: means that a file does not exist in s0&s1,
             ;                        means that a sector is not in use in s2.
    ldx #$03 ; initialise first 3 pages of volume only
_fmt_page:
    ldy #$00
_fmt_loop:
    sta (addr),y
    iny
    bne _fmt_loop
    inc addr+1
    dex
    bne _fmt_page

    dec addr+1

    ; the first 3 sectors are always reserved
    ldy #$00
    lda #$ff
    sta (addr),y
    iny
    sta (addr),y
    iny
    sta (addr),y
    iny

    ; this signature helps the os know that the filesystem in not corrupted
    ldy #$fc
    lda #$de
    sta (addr),y
    iny
    lda #$ad
    sta (addr),y
    iny
    lda #$be
    sta (addr),y
    iny
    lda #$ef
    sta (addr),y

    rts

; return if the disk is formatted with OZDOS-FS in carry
; expects: addr to contain the address of the current disk
; modifies: a, y
verify_disk:
  lda #02
  jsr get_sector

  ; TODO: maybe store DEADBEEF in rom somewhere and make this into a loop?
  ldy #252
  lda (addr),y
  cmp #$de
  bne _verify_disk_fail
  iny
  lda (addr),y
  cmp #$ad
  bne _verify_disk_fail
  iny
  lda (addr),y
  cmp #$be
  bne _verify_disk_fail
  iny
  lda (addr),y
  cmp #$ef
  bne _verify_disk_fail

  ; return the appropriate result in carry
  sec
  rts
_verify_disk_fail:
  clc
  rts

; ---------- ;
; user input ;
; ---------- ;

; run a full command, (re-enters the mainloop on error)
run_command:
  jsr show_prompt

  jsr get_line

  ; check if the input buffer is empty (its null terminated)
  ldx input_ptr
  lda input_buf,x
  beq _dispatch_loop_done

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
_dispatch_loop_done:
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
  jmp _show_prompt_trail
_show_prompt_not_a:
  cmp #1
  bne _show_prompt_not_b
  lda #"B"
  sta SERIAL
  jmp _show_prompt_trail
_show_prompt_not_b:
  lda #"T"
  sta SERIAL
_show_prompt_trail:
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
  cpx #0
  beq _get_line_backspace_ignore
  lda #"\b"
  sta SERIAL
  lda #" "
  sta SERIAL
  lda #"\b"
  sta SERIAL
  dex
_get_line_backspace_ignore:
  jmp _get_line_loop

; allow the user to type a varying length filename with a '.'
; modifies: a, x, y
expect_filename:
  ; everything below here is to get the filename to 12 chars.

  lda #12 ; 12 char filenames
  sta fname_left

  ldy #0
_expect_filename_nameloop:
  jsr expect_key
  cmp #"."
  beq _expect_filename_spaces
  sta filename,y
  iny
  dec fname_left
  jmp _expect_filename_nameloop
_expect_filename_spaces:
  lda #" "
  sta filename,y
  iny
  dec fname_left
  bne _expect_filename_spaces
  
  jsr expect_key
  sta filename+12
  jsr expect_key
  sta filename+13
  jsr expect_key
  sta filename+14

  lda #0
  sta filename+15

  rts

; expect a single character from input buffer and change to the appopriate disk
; note: will fail using bad_handler if a disk is not found (don't use this
;       subroutine outside of the command loop)
; expects:
; modifies: a
chdisk:
  jsr expect_key
  cmp #"a"
  beq _chdisk_a
  cmp #"b"
  beq _chdisk_b
  cmp #"t"
  beq _chdisk_t
  jmp bad_handler
_chdisk_a:
  lda #A
  sta disk
  rts
_chdisk_b:
  lda #B
  sta disk
  rts
_chdisk_t:
  lda #T
  sta disk
  rts


; return (in a) the sector id of a file name
; returns $ff if the file cannot be found
; expects: filename to be filled
; modifies: a, x, y
get_fileid:
  ; go to sector 0
  jsr get_disk

_get_fileid_loop:
  ; check the file for a match
  jsr _get_fileid_match
  beq _get_fileid_matched

  ; skip over the sector id
  lda addr
  clc
  adc #16
  sta addr
  bcc _get_fileid_no_carry
  inc addr+1
_get_fileid_no_carry:

  jmp _get_fileid_loop

  ; if not returned yet, not match found so return $ff
  lda #$ff
  rts

_get_fileid_matched:
  ; load the sector id
  ldy #15
  lda (addr),y
  rts

  jsr inc_addr

_get_fileid_match:
  ldx #15
  ldy #0
_get_fileid_match_loop:
  lda filename,y
  ; pha
  ; lda (addr),y
  ; sta SERIAL
  ; pla
  cmp (addr),y    ; no modifying addr
  bne _get_fileid_match_fail
  iny
  dex
  bne _get_fileid_match_loop
  lda #$00
  rts

_get_fileid_match_fail:
  lda #$ff
  rts

; expect from the input buffer and return (in a) a single key, ignoring spaces
; modifies: a, x
expect_key:
  ldx input_ptr
  inc input_ptr        ; move the buf ptr to the next char
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
  .byte "cat"
  .word  cat
  .byte "exe"
  .word  exe
  .byte "hlp"
  .word  hlp
  .byte "cls"
  .word  cls
  .byte "dsk"
  .word  dsk
  .byte "fmt"
  .word  fmt

dsk:
  ; store the old disk in case the verification fails
  lda disk
  pha
  jsr chdisk
  jsr get_disk
  jsr verify_disk
  pla
  bcs _dsk_verif_good
  sta disk
  lda #unfmted_msg
  sta PRINT
  lda #>unfmted_msg
  sta PRINT+1
  jsr print
_dsk_verif_good
  rts

; list the files in the current disk out to the serial port
; expects: addr to hold the address of the current disk
; modifies: a, x, y
lst:
  lda #lst_msg
  sta PRINT
  lda #>lst_msg
  sta PRINT+1
  jsr print

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
  cpx #"0"
  beq _usg_skip_leading_zero
  stx SERIAL
_usg_skip_leading_zero:
  sty SERIAL
  lda #usg_msg
  sta PRINT
  lda #>usg_msg
  sta PRINT+1
  jsr print
  rts

cat:
  ; testing the new filename routine
  ; jsr expect_filename
  ; lda #filename
  ; sta PRINT
  ; lda #>filename
  ; sta PRINT+1
  ; jsr print
  ; lda #"\n"
  ; sta SERIAL
  ; rts

  ; write the file to FILELOAD
  lda #>FILELOAD
  sta fileop_ptr+1
  lda #FILELOAD
  sta fileop_ptr

  ; read file starting at give sector
  jsr expect_filename
  jsr get_fileid
  jsr read_file

  lda #>FILELOAD
  sta addr+1
  lda #FILELOAD
  sta addr

  ldy #0
_cat_loop:
  lda (addr),y
  sta SERIAL

  inc addr
  bne _cat_no_carry
  inc addr+1
_cat_no_carry:
  ; check if we have reached the end of the file
  lda addr+1
  cmp fileop_ptr+1
  bne _cat_loop
  lda addr
  cmp fileop_ptr
  bne _cat_loop

_cat_done:
  lda #"\n"
  sta SERIAL
  rts

exe:
  ; write the file to FILELOAD
  lda #>FILELOAD
  sta fileop_ptr+1
  lda #FILELOAD
  sta fileop_ptr

  ; read file starting at given sector
  jsr get_byte
  jsr read_file

  ; actually run the file
  jsr FILELOAD
  rts

hlp:
  lda #hlp_msg
  sta PRINT
  lda #>hlp_msg
  sta PRINT+1
  jsr print
  lda #hlp_msg_2
  sta PRINT
  lda #>hlp_msg_2
  sta PRINT+1
  jsr print
  lda #hlp_msg_3
  sta PRINT
  lda #>hlp_msg_3
  sta PRINT+1
  jsr print
  rts

cls:
  lda #$11
  sta SERIAL
  rts

fmt:
  lda disk
  sta byte
  jsr chdisk
  jsr get_disk
  jsr fmt_disk
  lda byte
  sta disk
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

; expect a key and return (in a) the value of a single hex char
; modifies: a (duh)
get_nibble:
  jsr expect_key
  cmp #$3a
  bcc _get_nibble_digit
  sec
  sbc #"a" - 10
  rts
_get_nibble_digit:
  sbc #"0" - 1
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

; NOTE to self, remember to change to version numbers!

welcome_msg:
  .byte CLEAR
  .byte "**** Ozpex DOS v0.3.1 ****\n"
  .byte "Temp disk ready.\n\n"

  .byte "Type 'hlp' for help.\n\n"
  .byte 0

hlp_msg:
  .byte "Ozpex DOS Commands:\n"
  .byte "These commands are included in ROM.\n\n"
  .byte "lst: List all files on the disk\n"
  .byte "dsk: Switch between Disk A, B and T.\n", 0
hlp_msg_2: 
  .byte "exe: Execute an *.img program.\n"
  .byte "cat: Output the contents of a text file.\n"
  .byte "del: Delete a file.\n"
  .byte "cpy: Copy a file to another name.\n", 0
hlp_msg_3:
  .byte "cls: Clear the screen.\n"
  .byte "hlp: Display this help message.\n"
  .byte "usg: Check disk usage info.\n", 0
  .byte "fmt: Format a blank drive with OZDOS-FS.\n", 0

lst_msg:
  .byte "Filename     Ext | ID\n"
  .byte "-----------------+---\n"
  .byte 0

err_msg:
  .byte "\n"
  .byte ">:("
  .byte "\n"
  .byte 0

unfmted_msg:
  .byte "The drive has not been formatted for Ozpex DOS.\n"
  .byte "Try fmt <drive> on it.\n"
  .byte 0

usg_msg:
  .byte "*256B / 8K\n"
  .byte 0

delimiter:
  .byte " | "
  .byte 0

loading_file:
  .byte "Loading file..."
  .byte 0

  .org $fff8
  .word mainloop

  .org $fffc
  .word reset