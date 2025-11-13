  .org $0400

; ---- allocation ---- ;
scroll       = $40 ; 2 B

mode         = $42 ; 1 B

newlines     = $43 ; 2 B
scroll_count = $45 ; 2 B
ch           = $47 ; 1 B
; -------------------- ;

bufidx       = $48 ; 2 B

; ----- constants ----- ;
NORMAL                = 0
INSERT                = 1
; --------------------- ;

main:
  rts