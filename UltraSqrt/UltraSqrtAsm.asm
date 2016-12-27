;;***************************************************
;;
;; x64 ASM procedures for UltraSqrt
;;
;;***************************************************

PUBLIC  ?sqrt_init_qword@@YAHXZ             ; sqrt_init_qword
PUBLIC  ?sqrt_next_guess@@YAHXZ             ; sqrt_next_guess
PUBLIC  ?sqrt_check_next@@YAHXZ             ; sqrt_check_next
PUBLIC  ?sqrt_subtr_next@@YAHXZ             ; sqrt_subtr_next
PUBLIC  ?sqrt_bin_to_dec@@YAHXZ             ; sqrt_bin_to_dec

;;***************************************************
;; Extern data from 'UltraSqrt.cpp'
;;***************************************************
EXTRN    ?num@@3_KA         :QWORD          ; num
EXTRN    ?bas_beg@@3PEA_KEA :QWORD          ; bas_beg
EXTRN    ?bas_end@@3PEA_KEA :QWORD          ; bas_end
EXTRN    ?res_beg@@3PEA_KEA :QWORD          ; res_beg
EXTRN    ?res_mid@@3PEA_KEA :QWORD          ; res_mid
EXTRN    ?res_end@@3PEA_KEA :QWORD          ; res_end
EXTRN    ?lead@@3_KA        :QWORD          ; lead
EXTRN    ?next@@3_KA        :QWORD          ; next
EXTRN    ?shift@@3_KA       :QWORD          ; shift
EXTRN    ?hi_dec@@3_KA      :QWORD          ; hi_dec
EXTRN    ?lo_dec@@3_KA      :QWORD          ; lo_dec
EXTRN    ?adapt_stat@@3PA_KA:QWORD          ; adapt_stat

_TEXT   SEGMENT

;;***************************************************
;; PROC sqrt_init_qword
;;
;; - shifts 'num' (left so that 'sqrt(num)' contains
;;   1 in most significant bit of partial result
;; - conculates first QWORD of the 'sqrt(num)'
;;   bit by bit
;;***************************************************
?sqrt_init_qword@@YAHXZ PROC                ; sqrt_init_qword (==> shift)

    ;; num shift
        mov rax, ?num@@3_KA                 ; RAX <- num
        mov rcx, 32                         ; RCX (=shift) <- 32
        mov rdx, 4000000000000000h          ; RDX <- 010000..00b
    ;; shift by 2 bits until first 1 bit is on 1st or 2nd most significant pos.
    l_shift:
        cmp rax, rdx                        ; cmp RAX, RDX
        jae l_postshift                     ; if RAX >= RDX goto postshift
        shl rax, 2                          ; RAX (=num) << 2
        inc rcx                             ; ++ RCX
        jmp l_shift                         ; repeat
    l_postshift:
    ;; subtract first bit of result (always 1)
        sub rax, rdx                        ; RAX (=num) -= RDX (=part result)
    ;; cycle per all other bits except the last one
        mov rbx, 1000000000000000h          ; RBX (=next bit) <- RDX >> 2
    l_loop:
        mov rdi, rdx                        ; RDI <- RDX (temp result)
        add rdi, rbx                        ; RDI += RBX (=next bit)
        mov rsi, rax                        ; RSI <- RAX (temp num)
        sub rsi, rdi                        ; RSI -= RDI (temp sub)
        jb l_nosub                          ; if RSI < RDI goto nosub
        mov rdx, rdi                        ; RDX <- RDI (use temp reult)
        add rdx, rbx                        ; RDX += RBX (=next bit)
        mov rax, rsi                        ; RAX <- RSI (use temp num)
    l_nosub:
        shl rax, 1                          ; RAX (=num) << 1
        shr rbx, 1                          ; RBX (=next bit) >> 1
        jnz l_loop                          ; if RBX (=next bit) > 0 repeat
    ;; solve the last bit
        mov rdi, rdx                        ; RDI <- RDX (temp result)
        inc rdi                             ; ++ RDI (last bit)
        mov rsi, rax                        ; RSI <- RAX (temp num)
        sub rsi, rdi                        ; RSI -= RDI (temp sub)
        jb l_nolast                         ; if RSI < RDI goto nolast
        mov rdx, rdi                        ; RDX <- RDI (use temp reult)
        mov rax, rsi                        ; RAX <- RSI (use temp num)
        inc rbx                             ; ++ RBX (remember last bit)
    l_nolast:
        shl rax, 1                          ; RAX (=num) << 1
        add rax, rbx                        ; RAX += RBX (add last bit)
        shl rdx, 1                          ; RDX (=part result) << 1
    ;; fill shift
        mov ?shift@@3_KA, rcx               ; shift <- RCX
    ;; initiation of the base = actual base and rest = first double-word of the result
        mov rdi, ?bas_beg@@3PEA_KEA         ; move remainder of the rooted number to field "base"
        mov [rdi], rax                      ; base[base_beg] <- RAX
        mov rsi, ?res_beg@@3PEA_KEA         ; move partial resuilt to field "rest"
        mov [rsi], rdx                      ; rest[res_beg] <- RDX

    ret 0

?sqrt_init_qword@@YAHXZ ENDP                ; sqrt_init_qword

;;***************************************************
;; PROC sqrt_next_guess
;;
;; - calculate first approximation of the 'next'
;;   QWORD of partial result using 2 QWORDs from
;;   base and 'lead' of the partial result
;;***************************************************
?sqrt_next_guess@@YAHXZ PROC                ; sqrt_next_guess (==> next)

    mov rbx, ?lead@@3_KA                    ; RBX <- lead
    mov rdi, ?bas_beg@@3PEA_KEA             ; RDI iter <- bas_beg
    mov rdx, [rdi]                          ; RDX <- base[iter]
    mov rax, [rdi+8h]                       ; RAX <- base[iter+1]
    div rbx                                 ; RDX:RAX / RBX -> RAX, rest RDX
    mov ?next@@3_KA, rax                    ; next <- RAX

    ret 0

?sqrt_next_guess@@YAHXZ ENDP                ; sqrt_next_guess

;;***************************************************
;; PROC sqrt_check_next
;;
;; - checks and tries to adjust above calculated 'next'
;; - 'next' can be either left unchanged or adjusted
;;   to either 'next+1' or even 'next+2'
;;***************************************************
?sqrt_check_next@@YAHXZ PROC                ; sqrt_check_next (==> next, adjust)

    ;; reset adapt counter and read "next"
        xor r9, r9                          ; R9 adjust <- 0
        mov rbx, ?next@@3_KA                ; RBX <- next
    ;; try next adaptation
    l_adjustnext:
        inc r9                              ; ++ R9 adjust
        inc rbx                             ; ++ RBX (=next)
    ;; check overload
        jz l_adjustback                     ; if ZF goto adjustback
    ;; update rest[end] with updated "next"
        mov rsi, ?res_end@@3PEA_KEA         ;
        mov [rsi], rbx                      ; rest[end] <- RBX
    ;; reset RCX (check carry) and base and rest iterators
        mov rdi, ?bas_beg@@3PEA_KEA         ; RDI iter <- base_beg
        mov rcx, [rdi]                      ; RCX (=check carry) <- base[iter]
        add rdi, 8h                         ; ++ RDI iter
        mov rsi, ?res_beg@@3PEA_KEA         ; RSI iter <- res_beg
        mov r8,  ?res_mid@@3PEA_KEA         ; R8 stopper <- res_mid
    ;; check if adjusted result is OK
    l_checkloop:
        mov rax, [rsi]                      ; RAX <- rest[iter]
        mul rbx                             ; RAX*RBX -> RDX:RAX
        sub rcx, rdx                        ; RCX -= RDX
        jc l_adjustback                     ; if CF goto adjustback
        mov rdx, [rdi]                      ; RDX <- base[iter]
        sub rdx, rax                        ; RDX -= RAX
        sbb rcx, 0h                         ; RXC -= 0 (with carry)
        jc l_adjustback                     ; if RCX < 0 goto adjustback
        jnz l_adjustnext                    ; if RCX > 0 goto adjustnext
        mov rcx, rdx                        ; otherwise RCX <- RDX
        add rdi, 8h                         ; ++ RDI iter
        add rsi, 8h                         ; ++ RSI iter
        cmp rsi, r8                         ; cmp RSI iter, R8 stopper
        jbe l_checkloop                     ; if iter <= res_mid repeat check
        jmp l_postadjust                    ; otherwise goto postadjust
    ;; decrease (back) next DWORD
    l_adjustback:
        dec r9                              ; -- R9 adjust
        dec rbx                             ; -- RBX
    ;; update next
    l_postadjust:
        mov ?next@@3_KA, rbx                ; next <- RBX
        lea r8, offset ?adapt_stat@@3PA_KA  ; R8 <- adapt_stat (ptr)
        inc qword ptr [r8+8*r9]             ; ++ adapt_stat[R9]

    ret 0

?sqrt_check_next@@YAHXZ ENDP                ; sqrt_check_next

;;***************************************************
;; PROC sqrt_subtr_next
;;
;; - subtracts from 'base' partial result multiplied
;;   by 'next'
;;***************************************************
?sqrt_subtr_next@@YAHXZ PROC                ; sqrt_subtr_next

    ;; fill registers
        mov rbx, ?next@@3_KA                ; RBX <- next
        xor rcx, rcx                        ; RCX (=mul carry) <- 0
        mov rdi, ?bas_end@@3PEA_KEA         ; RDI iter <- bas_end
        mov rsi, ?res_mid@@3PEA_KEA         ; RSI iter <- res_mid
        mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
    ;; subtract partial result from base in a loop
    l_mainloop:
        mov rax, [rsi]                      ; RAX <- rest[iter]
        mul rbx                             ; RAX * RBX -> RDX:RAX
        add rax, rcx                        ; RDX:RAX += RCX
        adc rdx, 0h                         ;  (with carry)
        sub [rdi], rax                      ; base[iter] -= RAX
        adc rdx, 0h                         ; RDX += 0 (with carry)
        mov rcx, rdx                        ; RCX (=mul carry) <- RDX
        sub rdi, 8h                         ; -- RDI iter
        sub rsi, 8h                         ; -- RSI iter
        cmp rsi, r8                         ; cmp RSI iter, R8 stopper
        jae l_mainloop                      ; if RSI iter >= res_beg repeat mainloop
        sub [rdi], rcx                      ; base[iter(=bas_beg)] -= RCX (last mul carry)
    ;; multiply "next" by 2 (with a carry)
        mov rsi, ?res_end@@3PEA_KEA         ;
        add [rsi], rbx                      ; rest[iter(=res_end)] += RBX (~mul res_end by 2x)
        adc qword ptr [rsi-8h], 0h          ; with carry to rest[iter-1]

    ret 0

?sqrt_subtr_next@@YAHXZ ENDP                ; sqrt_subtr_next

;;***************************************************
;; PROC sqrt_bin_to_dec
;;
;; - converts binary result from 'rest'
;;   to decimal result in 'base' multiplying
;;   'rest' by 5^27 to get next 27 digits
;;   and additionally shifting the head by 27 bits
;;***************************************************
?sqrt_bin_to_dec@@YAHXZ PROC                ; sqrt_bin_to_dec

        mov rsi, ?res_end@@3PEA_KEA         ; RSI iter <- res_end
        mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
        mov r9,  ?res_mid@@3PEA_KEA         ; R9 stopper <- res_mid
    ;; clean top bits in rest[res_beg]
        mov rcx, ?shift@@3_KA               ; RCX <- shift
        mov rbx, [r8]                       ; RBX <- rest[res_beg]
        xor rax, rax                        ; RAX <- 0h
        shrd rax, rbx, cl                   ; RAX <- RBX >> shift
        xor rbx, rbx                        ; RBX <- 0h
        shld rbx, rax, cl                   ; RBX <- RAX << shift
        mov [r8], rbx                       ; rest[res_beg] <- RBX
    ;; preparing registers
        xor rax, rax                        ; RAX (=tail zero) <- 0h
        mov rbx, 7450580596923828125        ; RBX <- 5^27
        xor rcx, rcx                        ; RCX (=mul carry) <- 0
    ;; checking rest[res_end] if it is zero
    l_zerocheck:
        cmp rsi, r9                         ; cmp RSI iter, res_mid
        ja l_dozero                         ; if iter > res_mid goto dozero
        cmp rsi, r8                         ; cmp RSI iter, res_beg
        jb l_dechead                        ; if iter < stopper goto dechead
        mov rax, [rsi]                      ; RAX <- rest[res_end]
        cmp rax, 0h                         ; cmp RAX, 0h
        jnz l_decloop                       ; if rest[res_end] != 0 goto decloop
    ;; either pass through 0h values or explicitly clean values behind res_mid
    l_dozero:
        mov [rsi], rax                      ; rest[iter] <- RAX (=0h)
        sub rsi, 8h                         ; -- RSI iter (=rest_end)
        mov ?res_end@@3PEA_KEA, rsi         ; res_end <- RSI iter
        jmp l_zerocheck                     ; repeat zerocheck
    ;; loop per actual length of the rest
    l_decloop:
        mov rax, [rsi]                      ; RAX <- rest[iter]
        mul rbx                             ; RAX * RBX(=5^27) -> RDX:RAX
        add rax, rcx                        ; RDX:RAX += RCX (=mul carry)
        adc rdx, 0h                         ;  (with carry)
        mov rcx, rdx                        ; RCX (=mul carry) <- RDX
        mov [rsi], rax                      ; rest[iter] <- RAX
        sub rsi, 8h                         ; -- RSI iter
        cmp rsi, r8                         ; cmp iter, stopper
        jae l_decloop                       ; if iter >= res_beg repeat decloop
    ;; head processing - shift by 2^27
    l_dechead:
        xor rbx, rbx                        ; RBX <- 0
        mov rdx, rcx                        ; RDX <- RCX (=last mul carry)
        mov rax, [r8]                       ; RAX <- rest[res_beg]
        mov rcx, ?shift@@3_KA               ; RCX <- shift
        sub rcx, 27                         ; RCX -= 27
        jae l_simple2mul                    ; if RCX >= 27 goto simple2mul
    ;; shift of res_beg by 1 QWORD, add 64 to shift
        mov [r8], rbx                       ; rest[rest_beg] <- 0
        add r8, 8h                          ; ++ R8 stopper
        mov ?res_beg@@3PEA_KEA, r8          ; res_beg <- R8 stopper
        mov rbx, rdx                        ; RBX <- RDX
        mov rdx, rax                        ; RDX <- RAX
        mov rax, [r8]                       ; RAX <- rest[res_beg]
        add rcx, 64                         ; RCX += 64
    ;; simple shift (without res_beg change)
    l_simple2mul:
        shrd rax, rdx, cl                   ; (RBX:)RDX:RAX >> CL
        shrd rdx, rbx, cl                   ;   top bits from RBX
        mov ?shift@@3_KA, rcx               ; shift <- RCX
    ;; split of "whole" part into 13 and 12 decimal digits
        mov rbx, 1000000000000              ; RBX <- 1,000,000,000,000
        div rbx                             ; RDX:RAX / RBX(=1e12) -> RAX, rest RDX
        mov ?hi_dec@@3_KA, rax              ; hi_dec <- RAX
        mov ?lo_dec@@3_KA, rdx              ; lo_dec <- RDX

    ret 0

?sqrt_bin_to_dec@@YAHXZ ENDP                ; sqrt_bin_to_dec

_TEXT   ENDS

END