; d‚compactage d'un fichier EXE
; version 1.00 (c) 1989 Fabrice Bellard
; … assembler avec A86.COM (mais c'est facile … assembler avec tasm ou masm
; en modifiant quelques instructions

STARTIP  equ word ptr [00h]
STARTCS  equ word ptr [02h]
STARTSP  equ word ptr [04h]
STARTSS  equ word ptr [06h]
; longueur de l'ensemble du programme lz
LENLZ    equ word ptr [08h]
DECALAGE equ word ptr [0Ah]
LENPROG  equ word ptr [0Ch]

; macro pour prendre un bit
GETBIT macro
 shr bp,1
 dec dx
 jne >L01
 lodsw
 mov bp,ax
 mov dl,16
L01:
#EM


; d‚but en offset 000Eh
 org 0Eh

 push es
 push cs
 pop ds
 mov cx,LENPROG
 mov si,cx
 dec si
 mov di,si
 mov bx,ds
 add bx,DECALAGE
 mov es,bx
 std
 rep movsb
 push bx
 mov ax,offset SUITE
 push ax
 retf

SUITE:
; d‚placement du code LZ vers le haut de la RAM
 cs mov bp,LENLZ
 mov dx,ds
DEPL10:
 mov ax,bp
 cmp ax,1000h
 jbe DEPL05
 mov ax,1000h
DEPL05:
 sub bp,ax
 sub dx,ax
 sub bx,ax
 mov ds,dx
 mov es,bx
 mov cl,3
 shl ax,cl
 mov cx,ax
 shl ax,1
 dec ax
 dec ax
 mov si,ax
 mov di,ax
 rep movsw
 or bp,bp
 jne DEPL10


; d‚but du d‚compactage
 cld
 mov es,dx
 mov ds,bx
 xor si,si
 xor di,di
 mov dx,16
 lodsw
 mov bp,ax

DECOMP10:
 GetBit
 jnc DECOMP20
; pour les tests
; lodsb
; mov ah,0
; cs sub CRC2,ax
; cs inc SIZE
; stosb
 movsb
 jmp DECOMP10

; lecture dans le buffer
DECOMP20:
 xor cx,cx
 GetBit
 jc decomp30
; adresse sur 1 octet
 GetBit
 rcl cx,1
 GetBit
 rcl cx,1
 inc cx
 inc cx
 lodsb
 mov bh,0FFh
 mov bl,al
 jmp DECOMP40
; adresse sur 2 octets
DECOMP30:
 lodsw
 mov bx,ax
 mov cl,3
 shr bh,cl
 or bh,0E0h
 and ah,7
 je DECOMP39
 mov cl,ah
 inc cx
 inc cx
DECOMP40:
 es mov al,[bx+di]
; pour les tests
; mov ah,0
; cs sub CRC2,ax
; cs inc SIZE
 stosb
 loop DECOMP40
 jmp DECOMP10

; adresse sur 3 octets
DECOMP39:
 lodsb
 or al,al
 je FINDCMP
 cmp al,1
 je decomp50
 mov cl,al
 inc cx
 jmp DECOMP40

; mise … jour de es:di et ds:si
DECOMP50:
 mov bx,di
 and di,000Fh
 add di,2000h
 mov cl,4
 shr bx,cl
 mov ax,es
 add ax,bx
 sub ax,200h
 mov es,ax

 mov bx,si
 and si,000Fh
 shr bx,cl
 mov ax,ds
 add ax,bx
 mov ds,ax

 jmp decomp10

 DB '*FAB*'

; d‚compactage de la table de relocation
FINDCMP:
 push cs
 pop ds
RELOC03:
 mov si,offset RELOC
 pop bx
 add bx,10h
 mov dx,bx
 xor di,di
RELOC04:
 lodsb
 or al,al
 je RELOC10
 mov ah,0
RELOC07:
 add di,ax
 mov ax,di
 and di,000Fh
 mov cl,4
 shr ax,cl
 add dx,ax
 mov es,dx
 es add [di],bx
 jmp RELOC04
RELOC10:
 lodsw
 or ax,ax
 jne RELOC15
 add dx,0FFFh
 mov es,dx
 jmp RELOC04
RELOC15:
 cmp ax,1
 jne RELOC07

; lancement du programme EXE
RELOC20:
 mov ax,bx
 mov di,STARTSP
 mov si,STARTSS
 add si,ax
 add STARTCS,ax
 sub ax,10h
 mov ds,ax
 mov es,ax
 xor bx,bx
 cli
 mov ss,si
 mov sp,di
 sti
 cs jmp far [BX]

RELOC:


