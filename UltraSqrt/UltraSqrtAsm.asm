;;***************************************************
;;
;; x64 ASM procedures for UltraSqrt
;;
;;***************************************************

PUBLIC  ?sqrt_init_qword@@YAHXZ             ; sqrt_init_qword
PUBLIC  ?sqrt_guess_next@@YAHXZ             ; sqrt_guess_next
PUBLIC  ?sqrt_check_next@@YAHXZ             ; sqrt_check_next
PUBLIC  ?sqrt_subtr_next@@YAHXZ             ; sqrt_subtr_next
PUBLIC  ?sqrt_b2dec_init@@YAHXZ             ; sqrt_b2dec_init
PUBLIC  ?sqrt_b2dec_next@@YAHXZ             ; sqrt_b2dec_next

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
EXTRN    ?hi_dec@@3KA       :DWORD          ; hi_dec
EXTRN    ?mi_dec@@3KA       :DWORD          ; mi_dec
EXTRN    ?lo_dec@@3KA       :DWORD          ; lo_dec
EXTRN    ?dec_size@@3_KA    :QWORD          ; dec_size
EXTRN    ?dec_mul@@3_KA     :QWORD          ; dec_mul
EXTRN    ?dec_split@@3_KA   :QWORD          ; dec_split

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
        mov rbx, rdx                        ;
        shr rbx, 2                          ; RBX (=next bit) <- RDX >> 2
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
;; PROC sqrt_guess_next
;;
;; - calculate first approximation of the 'next'
;;   QWORD of partial result using 2 QWORDs from
;;   base and 'lead' of the partial result
;;***************************************************
?sqrt_guess_next@@YAHXZ PROC                ; sqrt_guess_next

    ;; divide 'base[bas_beg]:base[bas_beg+1]' by 'lead' to get "initial" value of 'next'
        mov rbx, ?lead@@3_KA                ; RBX <- lead
        mov rdi, ?bas_beg@@3PEA_KEA         ; RDI iter <- bas_beg
        mov rdx, [rdi]                      ; RDX <- base[iter]
        mov rax, [rdi+8h]                   ; RAX <- base[iter+1]
        div rbx                             ; RDX:RAX / RBX -> RAX, rest RDX
        mov ?next@@3_KA, rax                ; next <- RAX

    ret 0

?sqrt_guess_next@@YAHXZ ENDP                ; sqrt_guess_next

;;***************************************************
;; PROC sqrt_check_next
;;
;; - checks and tries to adjust above calculated 'next'
;; - 'next' can be either left unchanged or adjusted
;;   to either 'next+1' or even 'next+2'
;;***************************************************
?sqrt_check_next@@YAHXZ PROC                ; sqrt_check_next (==> next, adjust)

    ;; reset adapt counter and read "next"
        mov rbx, ?next@@3_KA                ; RBX <- next
    ;; try next adaptation
    l_adjustnext:
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
;; PROC sqrt_b2dec_init
;;
;; - converts top bits of binary result from 'rest'
;;   to decimal output
;;***************************************************
?sqrt_b2dec_init@@YAHXZ PROC                ; sqrt_b2dec_init

    ;; read and shift rest[res_beg] to get initial whole part
        mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
        mov rax, [r8]                       ; RAX <- rest[res_beg]
        mov rcx, ?shift@@3_KA               ; RCX <- shift
        shrd rsi, rax, cl                   ; RSI <- store bottom CL bits of RAX
        shr rax, cl                         ; RAX >> CL
        mov ?hi_dec@@3KA, eax               ; hi_dec <- EAX (32 bits only)
    ;; clean (already) used top bits from rest[res_beg]
        xor rax, rax                        ; RAX <- 0
        shld rax, rsi, cl                   ; RAX <- restore bottom CL bits from RSI
        mov [r8], rax                       ; rest[res_beg] <- RAX

    ret 0

?sqrt_b2dec_init@@YAHXZ ENDP                ; sqrt_b2dec_init

;;***************************************************
;; PROC sqrt_b2dec_next
;;
;; - converts binary result from 'rest'
;;   to decimal result multiplying 'rest'
;;   by 5^27 (instead of 10^27)
;;   and additionally shifting the head
;;   of the result by remaining 27 bits
;;***************************************************
?sqrt_b2dec_next@@YAHXZ PROC                ; sqrt_b2dec_next

    ;; read iterators and stoppers
        mov rsi, ?res_end@@3PEA_KEA         ; RSI iter <- res_end
        mov r8,  ?res_beg@@3PEA_KEA         ; R8 stopper <- res_beg
        mov r9,  ?res_mid@@3PEA_KEA         ; R9 stopper <- res_mid
    ;; prepare registers
        xor rax, rax                        ; RAX (=tail zero) <- 0h
        mov rbx, ?dec_mul@@3_KA             ; RBX <- dec_mul
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
        mov rcx, ?shift@@3_KA               ; RCX <- shift
        sub rcx, ?dec_size@@3_KA            ; RCX -= dec_size
        jae l_nobegshift                    ; if RCX >= dec_size goto nobegshift
    ;; shift of res_beg by 1 QWORD, add 64 to shift
        xchg rbx, rdx                       ; RBX <-> RDX (<- 0)
        xchg rdx, [r8]                      ; RDX <-> rest[res_beg] (<- 0)
        add r8, 8h                          ; ++ R8 stopper
        mov ?res_beg@@3PEA_KEA, r8          ; res_beg <- R8 stopper
        add rcx, 64                         ; RCX += 64
    ;; simple "whole" part bit separation (without res_beg shift)
    l_nobegshift:
        mov ?shift@@3_KA, rcx               ; shift <- RCX (updated value stored)
        mov rax, [r8]                       ; RAX <- rest[res_beg]
        shrd rsi, rax, cl                   ; RSI <- store bottom CL bits of RAX
        shrd rax, rdx, cl                   ; (RBX:)RDX:RAX >> CL
        shrd rdx, rbx, cl                   ;   top bits filled from RBX
    ;; split of the "integer" part into hi_dec:mi_dec:lo_dec DWORDs
        mov rbx, ?dec_split@@3_KA           ; RBX <- dec_split
        mov rdi, rax                        ; Split bin RDX:RAX -> dec EAX:EDX:EDI
        mov rax, rdx                        ; 1st DIV+XCHG: RDI <- orig RDX / RBX
        xor rdx, rdx                        ; 1st DIV+XCHG: RDX <- orig RDX % RBX
        div rbx                             ; 1st DIV+XCHG: RAX <- orig RAX
        xchg rax, rdi                       ; 2nd DIV+XCHG: RDX:RAX <- orig RDX:RAX / RBX
        div rbx                             ; 2nd DIV+XCHG: (EDI) RDI <- orig RDX:RAX % RBX
        xchg rdx, rdi                       ; 3rd DIV     : (EDX) RDX <- orig RDX:RAX / RBX % RBX
        div rbx                             ; 3rd DIV     : (EAX) RAX <- orig RDX:RAX / RBX / RBX
        mov ?lo_dec@@3KA, edi               ; lo_dec <- EDI (32 bits only)
        mov ?mi_dec@@3KA, edx               ; mi_dec <- EDX (32 bits only)
        mov ?hi_dec@@3KA, eax               ; hi_dec <- EAX (32 bits only)
    ;; clean (already) used top bits from rest[res_beg]
        xor rax, rax                        ; RAX <- 0
        shld rax, rsi, cl                   ; RAX <- restore bottom CL bits from RSI
        mov [r8], rax                       ; rest[res_beg] <- RAX

    ret 0

?sqrt_b2dec_next@@YAHXZ ENDP                ; sqrt_b2dec_next

_TEXT   ENDS

END