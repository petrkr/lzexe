; LZEXE-compatible 8086 EXE decompressor.
; Original version © 1989 Fabrice Bellard.
; NASM port © 2026 Petr Kracik.
; A 14-byte private header precedes this code.

bits 16
org 0x0e

STARTIP  equ 0x00
STARTCS  equ 0x02
STARTSP  equ 0x04
STARTSS  equ 0x06
LENLZ    equ 0x08
DECALAGE equ 0x0a
LENPROG  equ 0x0c

%macro GETBIT 0
    shr bp, 1
    dec dx
    jnz %%done
    lodsw
    mov bp, ax
    mov dl, 16
%%done:
%endmacro

    push ax                    ; 0.91e preserves DOS entry AX
    push es
    push cs
    pop ds
    mov cx, [LENPROG]
    db 0x8b, 0xf1              ; mov si,cx (A86 encoding)
    dec si
    mov di, si
    mov bx, ds
    add bx, [DECALAGE]
    mov es, bx
    std
    rep movsb
    push bx
    mov ax, SUITE
    push ax
    retf

SUITE:
    mov bp, [cs:LENLZ]
    mov dx, ds
DEPL10:
    mov ax, bp
    cmp ax, 0x1000
    jbe DEPL05
    mov ax, 0x1000
DEPL05:
    sub bp, ax
    sub dx, ax
    sub bx, ax
    mov ds, dx
    mov es, bx
    mov cl, 3
    shl ax, cl
    mov cx, ax
    shl ax, 1
    dec ax
    dec ax
    mov si, ax
    mov di, ax
    rep movsw
    or bp, bp
    jne DEPL10

    cld
    mov es, dx
    mov ds, bx
    xor si, si
    xor di, di
    mov dx, 16
    lodsw
    mov bp, ax
DECOMP10:
    GETBIT
    jnc DECOMP20
    movsb
    jmp DECOMP10
DECOMP20:
    xor cx, cx
    GETBIT
    jc DECOMP30
    GETBIT
    rcl cx, 1
    GETBIT
    rcl cx, 1
    inc cx
    inc cx
    lodsb
    mov bh, 0xff
    mov bl, al
    jmp DECOMP40
DECOMP30:
    lodsw
    mov bx, ax
    mov cl, 3
    shr bh, cl
    or bh, 0xe0
    and ah, 7
    jz DECOMP39
    mov cl, ah
    inc cx
    inc cx
DECOMP40:
    mov al, [es:bx+di]
    stosb
    loop DECOMP40
    jmp DECOMP10
DECOMP39:
    lodsb
    or al, al
    jz FINDCMP
    cmp al, 1
    je DECOMP50
    mov cl, al
    inc cx
    jmp DECOMP40
DECOMP50:
    mov bx, di
    and di, 0x000f
    add di, 0x2000
    mov cl, 4
    shr bx, cl
    mov ax, es
    add ax, bx
    sub ax, 0x0200
    mov es, ax
    mov bx, si
    and si, 0x000f
    shr bx, cl
    mov ax, ds
    add ax, bx
    mov ds, ax
    jmp DECOMP10

    db '*FAB*'
FINDCMP:
    push cs
    pop ds
RELOC03:
    mov si, RELOC
    pop bx
    add bx, 0x10
    mov dx, bx
    xor di, di
RELOC04:
    lodsb
    or al, al
    jz RELOC10
    mov ah, 0
RELOC07:
    add di, ax
    mov ax, di
    and di, 0x000f
    mov cl, 4
    shr ax, cl
    add dx, ax
    mov es, dx
    add [es:di], bx
    jmp RELOC04
RELOC10:
    lodsw
    or ax, ax
    jnz RELOC15
    add dx, 0x0fff
    mov es, dx
    jmp RELOC04
RELOC15:
    cmp ax, 1
    jne RELOC07
RELOC20:
    mov ax, bx
    mov di, [STARTSP]
    mov si, [STARTSS]
    add si, ax
    add word [STARTCS], ax
    sub ax, 0x10
    mov ds, ax
    mov es, ax
    xor bx, bx
    pop ax
    mov ss, si
    mov sp, di
    nop
    jmp far [cs:bx]
RELOC:
