;;***************************************************
;;
;; x64 ASM procedures for UltraSqrt
;;
;;***************************************************

PUBLIC  ?sqrt_init_qword@@YAHXZ             ; sqrt_init_qword
PUBLIC  ?sqrt_next_guess@@YAHXZ             ; sqrt_next_guess
PUBLIC  ?sqrt_check_next@@YAHXZ             ; sqrt_check_next
PUBLIC  ?sqrt_subtr_next@@YAHXZ             ; sqrt_subtr_next
PUBLIC  ?sqrt_shift_rest@@YAHXZ             ; sqrt_subtr_next
PUBLIC  ?sqrt_bin_to_dec@@YAHXZ             ; sqrt_bin_to_dec

;;***************************************************
;; Extern data from 'UltraSqrt.cpp'
;;***************************************************
EXTRN    ?num@@3_KA         :QWORD          ; num
EXTRN    ?base@@3PEA_KEA    :QWORD          ; base
EXTRN    ?rest@@3PEA_KEA    :QWORD          ; rest
EXTRN    ?bas_beg@@3PEA_KEA :QWORD          ; bas_beg
EXTRN    ?bas_end@@3PEA_KEA :QWORD          ; bas_end
EXTRN    ?res_beg@@3PEA_KEA :QWORD          ; res_beg
EXTRN    ?res_mid@@3PEA_KEA :QWORD          ; res_mid
EXTRN    ?res_end@@3PEA_KEA :QWORD          ; res_end
EXTRN    ?lead@@3_KA        :QWORD          ; lead
EXTRN    ?next@@3_KA        :QWORD          ; next
EXTRN    ?shift@@3_KA       :QWORD          ; shift
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
        mov rdi, ?base@@3PEA_KEA            ; move remainder of the rooted number to field "base"
        mov [rdi], rax                      ; base[0] <- RAX
        mov rsi, ?rest@@3PEA_KEA            ; move partial resuilt to field "rest"
        mov [rsi], rdx                      ; rest[0] <- RDX

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
;; PROC sqrt_shift_rest
;;
;; - shift (final) result back to revert inital shift
;;   applied in proc 'sqrt_init_qword' so that
;;   rest[0] contains whole part of the 'sqrt(num)'
;;***************************************************
?sqrt_shift_rest@@YAHXZ PROC                ; sqrt_subtr_next

    ;; download the number of bits into register
        mov rsi, ?res_end@@3PEA_KEA         ; RSI iter <- rest_end
        mov rax, [RSI]                      ; RAX <- rest[end]
		mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
        mov rcx, ?shift@@3_KA               ; RCX (resp. CL) <- shift
    ;; shift the array in the loop
    l_shiftloop:
        sub rsi, 8h                         ; -- RSI (=iter-1)
        mov rbx, [rsi]                      ; RBX <- rest[iter]
        shrd rax, rbx, cl                   ; RBX:RAX >> CL
        mov [rsi+8h], rax                   ; rest[iter+1] <- RAX
        mov rax, rbx                        ; RAX <- RBX
        cmp rsi, r8                         ; cmp RSI iter, R8 stopper
        ja l_shiftloop                      ; if iter > stopper repeat shiftloop
    ;; shift the last element
        shr rax, cl                         ; RAX >> CL
        mov [rsi], rax                      ; rest[iter(=res_beg)] <- RAX

    ret 0

?sqrt_shift_rest@@YAHXZ ENDP                ; sqrt_subtr_next

;;***************************************************
;; PROC sqrt_bin_to_dec
;;
;; - converts binary result from 'rest'
;;   to decimal result in 'base' multiplying
;;   'rest' by 5^25 to get next 25 digits
;;   (after result is additionally shifted by 2^25)
;;***************************************************
?sqrt_bin_to_dec@@YAHXZ PROC                ; sqrt_bin_to_dec

        mov rbx, 298023223876953125         ; RBX <- 5^25
        xor rcx, rcx                        ; RCX (=mul carry) <- 0
        mov rsi, ?res_end@@3PEA_KEA         ; RSI iter <- res_end
        mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
    ;; perform init zero check
    l_zerocheck:
        cmp rsi, r8                         ; cmp RSI iter, res_beg
        jb l_dechead                        ; if iter < stopper goto dechead
        mov rax, [rsi]                      ; RAX <- rest[res_end]
        cmp rax, 0h                         ; cmp RAX, 0h
        jnz l_decloop                       ; if rest[res_end] != 0 goto decloop
        sub rsi, 8h                         ; -- RSI iter (=rest_end)
        mov ?res_end@@3PEA_KEA, rsi         ; res_end <- RSI iter
        jmp l_zerocheck                     ; repeat zerocheck
    ;; loop per actual length of the rest
    l_decloop:
        mov rax, [rsi]                      ; RAX <- rest[iter]
        mul rbx                             ; RAX * RBX(=5^25) -> RDX:RAX
        add rax, rcx                        ; RDX:RAX += RCX (=mul carry)
        adc rdx, 0h                         ;  (with carry)
        mov rcx, rdx                        ; RCX (=mul carry) <- RDX
        mov [rsi], rax                      ; rest[iter] <- RAX
        sub rsi, 8h                         ; -- RSI iter
        cmp rsi, r8                         ; cmp iter, stopper
        jae l_decloop                       ; if iter >= res_beg repeat decloop
    ;; head processing - shift by 2^25
    l_dechead:
        xor rdx, rdx                        ; RDX = 0
        mov rax, rcx                        ; RAX <- RCX (=last mul carry)
        mov rcx, ?shift@@3_KA               ; RCX <- shift
        add rcx, 25                         ; RCX += 25
        cmp rcx, 64                         ; cmp RCX, 64
        jb l_simple2mul                     ; if RCX < 64 goto simple2mul
    ;; shift of res_beg by 1 QWORD
        sub rcx, 64                         ; RCX -= 64
        xchg rdx, rax                       ; RDX <-> RAX
        xchg rax, [r8]                      ; RAX <-> rest[rest_beg]
        add r8, 8h                          ; ++ R8 stopper
        mov ?res_beg@@3PEA_KEA, r8          ; res_beg <- R8 stopper
    ;; simple shift (without res_beg change)
    l_simple2mul:
        mov ?shift@@3_KA, rcx               ; shift <- RCX
        mov rbx, [r8]                       ; RBX <- rest[res_beg]
        shld rdx, rax, cl                   ; RDX:RAX << CL
        shld rax, rbx, cl                   ;   lower bits from RBX
        shl rbx, cl                         ; RBX cleaning of top bits
        shr rbx, cl                         ;   being shifted to RAX
        mov [r8], rbx                       ; rest[res_beg] <- RBX
    ;; split of "whole" part into 13 and 12 decimal digits and store at the end of base
        mov rbx, 1000000000000              ; RBX <- 1,000,000,000,000
        div rbx                             ; RDX:RAX / RBX(=1e12) -> RAX, rest RDX
        mov rdi, ?bas_end@@3PEA_KEA         ; RDI base_end <- bas_end
        mov [rdi+8h], rax                   ; base[base_end+1] <- higher dec digits
        mov [rdi+10h], rdx                  ; base[base_end+2] <- lower dec digits
        add rdi, 10h                        ; RDI base_end += 2
        mov ?bas_end@@3PEA_KEA, rdi         ; base_end <- RDI

    ret 0

?sqrt_bin_to_dec@@YAHXZ ENDP                ; sqrt_bin_to_dec

_TEXT   ENDS

END