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
PUBLIC  ?sqrt_split_deci@@YAHXZ             ; sqrt_split_deci

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
EXTRN    ?hi_dec@@3_KA      :QWORD          ; hi_dec
EXTRN    ?lo_dec@@3_KA      :QWORD          ; lo_dec
EXTRN    ?adapt@@3_KA       :QWORD          ; adapt

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
        mov ?adapt@@3_KA, 0                 ; adapt <- 0 (reset)
        mov rbx, ?next@@3_KA                ; RBX <- next
    ;; try next adaptation
    l_adjustnext:
        inc ?adapt@@3_KA                    ; ++ adapt
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
        mov rcx, rdx                        ; otherwise RCX <- RCX
        add rdi, 8h                         ; ++ RDI iter
        add rsi, 8h                         ; ++ RSI iter
        cmp rsi, ?res_mid@@3PEA_KEA         ; cmp RSI iter, res_mid
        jbe l_checkloop                     ; if iter <= res_mid repeat check
        jmp l_postadjust                    ; otherwise goto postadjust
    ;; decrease (back) next DWORD
    l_adjustback:
        dec ?adapt@@3_KA                    ; -- adjust
        dec rbx                             ; -- RBX
    ;; update next
    l_postadjust:
        mov ?next@@3_KA, rbx                ; next <- RBX

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
        cmp rsi, ?res_beg@@3PEA_KEA         ; cmp RSI iter, res_beg
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
        mov rdi, ?res_end@@3PEA_KEA         ; RDI iter <- rest_end
        mov rcx, ?shift@@3_KA               ; RCX (resp. CL) <- shift
		mov rdx, ?res_beg@@3PEA_KEA         ; RDX <- res_beg
    ;; shift the array in the loop
    l_shiftloop:
        cmp rdi, rdx                        ; cmp RDI iter, RDX (=res_beg)
        jz l_shiftend                       ; if iter == res_beg goto shiftend
        mov rsi, rdi                        ; RSI <- RDI(=iter)
        sub rsi, 8h                         ; -- RSI (=iter-1)
        mov rax, [rdi]                      ; RAX <- rest[iter]
        mov rbx, [rsi]                      ; RBX <- rest[iter-1]
        shrd rax, rbx, cl                   ; RBX:RAX >> CL
        mov [rdi], rax                      ; rest[iter] <- RAX
        mov rdi, rsi                        ; iter RDI <- RSI (=iter-1)
        jmp l_shiftloop                     ; repeat shiftloop
    ;; shift the last element
    l_shiftend:
        mov rax, [rdi]                      ; RAX <- rest[iter(=(res_beg)]
        shr rax, cl                         ; RAX >> CL
        mov [rdi], rax                      ; rest[iter(=res_beg)] <- RAX

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
    ;; loop per actual length of the rest
        cmp rsi, ?res_beg@@3PEA_KEA         ; cmp RSI iter, res_beg
        jb l_decend                         ; if iter < res_beg goto decend
    l_decloop:
        mov rax, [rsi]                      ; RAX <- rest[iter]
        mul rbx                             ; RAX * RBX(=5^25) -> RDX:RAX
        add rax, rcx                        ; RDX:RAX += RCX (=mul carry)
        adc rdx, 0h                         ;  (with carry)
        mov rcx, rdx                        ; RCX (=mul carry) <- RDX
        mov [rsi], rax                      ; rest[iter] <- RAX
        sub rsi, 8h                         ; -- RSI iter
        cmp rsi, ?res_beg@@3PEA_KEA         ; cmp iter, res_beg
        jae l_decloop                       ; if iter >= res_beg repeat decloop
    l_decend:
        mov [rsi], rcx                      ; rest[iter(=0)] <- RCX (=last mul carry)

    ret 0

?sqrt_bin_to_dec@@YAHXZ ENDP                ; sqrt_bin_to_dec

;;***************************************************
;; PROC sqrt_split_deci
;;
;; - splits 25 digits binary stored in two QWORDs
;;   into two decimal groups
;; - 13 digits in HI QWORD 
;; - 12 digits in LO QWORD
;; - appends these QWORDs to the end of 'base'
;;***************************************************
?sqrt_split_deci@@YAHXZ PROC                ; sqrt_split_deci

    mov rcx, ?shift@@3_KA                   ; RCX (resp. CL) <- shift
    mov rax, ?lo_dec@@3_KA                  ; RDX:RAX <- hi_dec:lo_dec
    mov rdx, ?hi_dec@@3_KA                  ;
    mov rsi, ?res_beg@@3PEA_KEA             ; RSI iter <- res_beg
    mov rdi, ?bas_end@@3PEA_KEA             ; RDI iter <- bas_end
    mov rbx, [rsi]                          ; RBX <- rest[iter(=res_beg)]
    shld rdx, rax, cl                       ; RDX:RAX << CL
    shld rax, rbx, cl                       ;   (taking lower bits from RBX)
    shl rbx, cl                             ; RBX << CL
    shr rbx, cl                             ; RBX >> CL (cleaning of top bits)
    mov [rsi], rbx                          ; rest[iter(=res_beg)] <- RBX
    mov rbx, 1000000000000                  ; RBX <- 1,000,000,000,000
    div rbx                                 ; RDX:RAX / RBX(=1e12) -> RAX, rest RDX
    mov [rdi-8h], rax                       ; base[iter-1(=base_end-1)] <- higher dec digits
    mov [rdi], rdx                          ; base[iter(=base_end)] <- lower dec digits

    ret 0

?sqrt_split_deci@@YAHXZ ENDP                ; sqrt_split_deci

_TEXT   ENDS

END