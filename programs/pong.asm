    .org $8003

; memory map:
TIMER    = $8001
SERIAL   = $8002
EXIT_VEC = $fff8

; ascii codes:
NEWLINE   = $0a
CLEAR     = $11
ESCAPE    = $1b

; memory allocation:
player    = $30 ; 1 byte
ballx     = $32 ; 1 byte
bally     = $33 ; 1 byte
ballright = $34 ; 1 byte
ballup    = $35 ; 1 byte
iteration = $36 ; 1 byte
score     = $37 ; 1 byte
PRINT     = $38 ; 2 bytes

main:
  lda #7
  sta player
  sta ballx
  sta bally
  lda #0
  sta iteration
  sta score
  sta ballright
  sta ballup

loop:
  jsr get_input
  jsr move_ball
  jsr collide
  jsr draw

  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop

  inc iteration

  jmp loop

exit:
  jsr draw
  lda #exit_message
  sta PRINT
  lda #>exit_message
  sta PRINT + 1
  jsr print
_exit_loop:
  lda SERIAL
  cmp #NEWLINE
  beq _exit_restart
  cmp #ESCAPE
  bne _exit_loop
  lda #CLEAR
  sta SERIAL
  jmp (EXIT_VEC)
_exit_restart:
  jmp main

collide:
  lda ballx
  cmp #15
  bcc _collide_not_right
  lda #1
  sta ballright
  dec ballx
  dec ballx
_collide_not_right:

  lda ballx
  cmp #1
  bcs _collide_not_left
  lda bally
  cmp player
  bne exit
  inc score
  lda #0
  sta ballright
  inc ballx
  inc ballx
_collide_not_left:

  lda bally
  cmp #15
  bcc _collide_not_bottom
  lda #0
  sta ballup
_collide_not_bottom:

  lda bally
  cmp #1
  bcs _collide_not_top
  lda #1
  sta ballup
_collide_not_top:

  rts

draw:
  ; print the score message
  lda #score_message
  sta PRINT
  lda #>score_message
  sta PRINT + 1
  jsr print
  lda score
  jsr hex_byte
  cpx #"0"
  beq _draw_skip_leading_zero
  stx SERIAL
_draw_skip_leading_zero:
  sty SERIAL
  lda #NEWLINE
  sta SERIAL
  sta SERIAL

  ldy #0
_draw_y_loop:
  lda #line_start
  sta PRINT
  lda #>line_start
  sta PRINT + 1
  jsr print

  ldx #0
_draw_x_loop:
  cpx ballx
  bne _draw_dont_print_ball
  cpy bally
  bne _draw_dont_print_ball
  lda #ball
  sta PRINT
  lda #>ball
  sta PRINT + 1
  jsr print
  jmp _draw_x_loop_next
_draw_dont_print_ball:

  cpx #0
  bne _draw_dont_print_player
  cpy player
  bne _draw_dont_print_player
  lda #" "
  sta SERIAL
  lda #"|"
  sta SERIAL
  jmp _draw_x_loop_next
_draw_dont_print_player:

  cpx #15
  bne _draw_dont_print_ai
  cpy bally
  bne _draw_dont_print_ai
  lda #"|"
  sta SERIAL
  lda #" "
  sta SERIAL
  jmp _draw_x_loop_next
_draw_dont_print_ai:

  lda #" "
  sta SERIAL
  sta SERIAL

_draw_x_loop_next:
  inx
  cpx #16
  bne _draw_x_loop

  lda #line_trail
  sta PRINT
  lda #>line_trail
  sta PRINT + 1
  jsr print

  iny
  cpy #16
  bne _draw_y_loop

; move the ball based on ballright and ballup
move_ball:
  lda iteration
  and #%00000001
  bne _move_ball_ret
  
  lda ballright
  beq _move_ball_right
  dec ballx
  jmp _move_ball_check_up
_move_ball_right:
  inc ballx
_move_ball_check_up:
  lda iteration
  and #%0000011
  bne _move_ball_ret

  lda ballright
  lda ballup
  beq _move_ball_up
  inc bally
  rts
_move_ball_up:
  dec bally
_move_ball_ret:
  rts

get_input:
  lda SERIAL

  ; if they pressed w or s, move the player
  cmp #"w"
  beq _get_input_w
  cmp #"s"
  beq _get_input_s

  ; otherwise return
  rts
_get_input_w:
  dec player
  jmp _get_input_wrap
_get_input_s:
  inc player
_get_input_wrap:
  ; keep the player on screen
  lda player
  and #$0f
  sta player
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

score_message:
  .byte CLEAR
  .byte ESCAPE, "[7m"
  .byte " O64 Pong v1.0.4 "
  .byte ESCAPE, "[0m", NEWLINE
  .byte "Score: ", 0
line_start:
  .byte "|| ", 0
line_trail:
  .byte " ||", NEWLINE, 0
exit_message:
  .byte NEWLINE
  .byte "**** Game Over! ****", NEWLINE
  .byte "Press enter to play again.", NEWLINE
  .byte "Press escape to exit.", NEWLINE
  .byte 0
ball:
  .byte "##", 0