; routines asm pour lzss (c) 1989 F. Bellard


DATA segment public

; constantes
BUFSIZE equ 2000h
RIEN    equ BUFSIZE*2
LENMAX  equ 253
TABSIZE equ 4096
TABAND  equ 0FFFh

TBUF		db (BUFSIZE+LENMAX+1) dup(?)
			even
RSON		dw (BUFSIZE+TABSIZE+1) dup(?)
DAD    		dw BUFSIZE+1 dup(?)
MATCHLEN 	dw ?
LENREST		dw ?
MATCHPOS 	dw ?
MATCHNPOS 	dw ?

; pour les EXE
SEGSIZE     dw ?
ECART		dw ?
	extrn ECARTMAX:word

CODEPTR  	dw ?
MASQUE   	dw ?
CODEBUF  	dw ?
CODEBUF1    db 128 dup(?)


; disk buffer I/O
	extrn GETBUFIN:dword
	extrn PUTBUFOUT:dword

	extrn SEGBUFIN:word
	extrn SEGBUFOUT:word
	extrn OFSBUFIN:word
	extrn OFSBUFOUT:word

    extrn BUFINSIZEM:word
   	extrn BUFOUTSIZEM:word

BUFINPTR 	dw ?
BUFOUTPTR 	dw ?
BUFINSIZE 	dw ?
BUFOUTSIZE  dw ?

DATA ends


CODE segment public

	assume cs:CODE,ds:DATA

	public LZCOMP


PUTBUF proc near
	push bx
	push cx
	push dx
	push si
	push di
	push es
	mov ax,BUFOUTSIZEM
	mov BUFOUTSIZE,ax
	mov ax,BUFOUTPTR
	mov bx,OFSBUFOUT
	sub ax,bx
	mov BUFOUTPTR,bx
	push ax
	call [PUTBUFOUT]
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
PUTBUF endp

GETBUF proc near
	push bx
	push cx
	push dx
	push si
	push di
	push es
	mov ax,OFSBUFIN
	mov BUFINPTR,ax
	call [GETBUFIN]
	inc ax
	mov BUFINSIZE,ax
	dec ax
	pop es
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
GETBUF endp

OPENIO proc near
	mov BUFINSIZE,1
	mov ax,OFSBUFOUT
	mov BUFOUTPTR,ax
	mov ax,BUFOUTSIZEM
	mov BUFOUTSIZE,ax
	ret
OPENIO endp

CLOSEIO proc near
	call PUTBUF
	ret
CLOSEIO endp




; gestion de la sortie de bits et octets
; sortie du buffer
PutCodeBuf proc near
	mov si,offset CODEBUF
	mov es,SEGBUFOUT
PUTCODE05:
	inc ECART
	lodsb
	mov BX,BUFOUTPTR
	inc BUFOUTPTR
	mov es:[bx],al
	dec BUFOUTSIZE
	jne PUTCODE10
	call PUTBUF
PUTCODE10:
	cmp si,CODEPTR
	jne PUTCODE05

	mov MASQUE,1
	mov CODEBUF,0
	mov CODEPTR,offset CODEBUF1
	ret
PutCodeBuf endp


; sortie d'un bit
PutBit proc near
	or al,al
	je PUTBIT05
	mov ax,MASQUE
	or CODEBUF,ax
PUTBIT05:
	shl MASQUE,1
	jne PUTBIT10
	call PutCodeBuf
PUTBIT10:
	ret
PutBit endp


; sortie d'un caractŠre
PutCh proc near
	mov di,CODEPTR
	inc CODEPTR
	mov [di],al
	ret
PutCh endp

; **************************************************************************
; sous programmes pour la compression
; **************************************************************************



; **************************************************************************
; stocker le caractŠre point‚ par R dans l'arbre
; **************************************************************************
; R=di
; S=si
;	q:=BufSize+1+byte(TBuf[r]);
;	rson[r]:=rson[q];
;	dad[rson[q]]:=r;
;	rson[q]:=r;
;	dad[r]:=q;

InsertNode proc near
	push si
	push di
	mov ax,[di+offset TBUF]
	and ax,TABAND
	shl ax,1
	add ax,RIEN+2
	mov si,ax
	shl di,1
	mov bx,[si+offset RSON]
	mov [di+offset RSON],bx
	mov [bx+offset DAD],di
	mov [si+offset RSON],di
	mov [di+offset DAD],si
	pop di
	pop si
	ret
InsertNode endp


; **************************************************************************
; tester la chaine point‚e par R avec le buffer puis la mettre dans l'arbre
; **************************************************************************

TestMatch proc near
	push si
	push di

	push di
	add di,offset TBUF
	mov dx,di
	inc dx
    mov bx,[di]
	and bx,TABAND
	shl bx,1
	add bx,RIEN+2
	push bx
	mov ax,LENMAX-1
	push ds
	pop es
TEST05:
	mov bx,[bx+offset RSON]
	cmp bx,RIEN
	jz TEST15
	mov si,bx
	shr si,1
	add si,(offset TBUF)+1
    mov di,dx
	mov cx,LENMAX-1
    repz cmpsb
	je TEST10
	cmp cx,ax
	jae TEST05
	mov bp,bx
	mov ax,cx
	jmp TEST05
TEST10:
	mov bp,bx
	mov ax,0FFFFh
TEST15:
	pop si
	pop di
	shl di,1
; calcul de matchlen
	mov cx,LENMAX
	sub cx,ax
	dec cx
	mov MATCHLEN,cx
; calcul de matchpos
	mov ax,di
	sub ax,bp
	shr ax,1
	and ax,(BufSize-1)
	mov MATCHPOS,ax
	not ax
	inc ax
	mov MATCHNPOS,ax

; insertion du noeud
	mov bx,[si+offset RSON]
	mov [di+offset RSON],bx
	mov [bx+offset DAD],di
	mov [si+offset RSON],di
	mov [di+offset DAD],si
; fin
    pop di
	pop si
	ret
TestMatch endp


; **************************************************************************
; effacer un noeud en si
; **************************************************************************
;procedure DeleteNode(p:word);
;var q:word;
;begin
;	if dad[p]=Rien then exit;
;	rson[dad[p]]:=rson[p];
;	dad[rson[p]]:=dad[p];
;	dad[p]:=rien;
;end;

DeleteNode proc near
	shl si,1
	mov bx,[si+offset DAD]
	cmp bx,RIEN
	je DEL90
	mov [bx+offset RSON],RIEN
	mov [si+offset DAD],RIEN
DEL90:
	shr si,1
	ret
DeleteNode endp



; **************************************************************************
; programme principal de compression
; **************************************************************************

LZCOMP proc far

	push bp
	mov bp,sp

	push ds
	pop es

	call OPENIO

	mov cx,BufSize
	mov ax,RIEN
	mov di,offset DAD
	rep stosw

 	mov cx,BufSize+TABSIZE+1
 	mov di,offset RSON
 	rep stosw

	mov di,offset TBUF
	mov cx,BufSize+LenMax-1
	mov al,00h
	rep stosb


; codebuf
	mov MASQUE,1
	mov CODEPTR,offset CODEBUF1
	xor ax,ax
	mov CODEBUF,ax
	mov SEGSIZE,ax
	mov ECART,ax
	mov ECARTMAX,ax

; lecture des premiers octets
	mov di,(offset TBUF)+BUFSIZE-LENMAX
	mov cx,LENMAX
	mov es,SEGBUFIN
S3A0F:
	dec BUFINSIZE
	jne S3A24
	call GETBUF
	or ax,ax
	je S3A2E
	jmp S3A0F
S3A24:
	mov BX,BUFINPTR
	inc BUFINPTR
	mov al,es:[BX]
	mov [di],al
	inc di
	loop S3A0F

S3A2E:
	mov AX,LENMAX
	sub AX,CX
	mov LENREST,AX

	mov DI,BUFSIZE-LENMAX
	xor SI,SI
	call TESTMATCH



; boucle de compression

S3A55:
	mov ax,MATCHLEN
	cmp ax,LENREST
	jle S3A67
	mov ax,LENREST
	mov MATCHLEN,ax

S3A67:
	push SI
	push DI
	cmp ax,2
	jb LB26
	ja L30
	cmp MatchPos,256
	jb L30
LB26:
; on envoie l'octet non cod‚
	mov MatchLen,1
	mov al,1
	call PutBit
	mov al,[di+offset TBUF]
	call PutCh
	jmp L35

L30:
	mov al,0
	call PutBit

	cmp MatchLen,5
	ja LA05
	cmp MATCHPOS,256
	jae LA05
; matchpos sur 1 octet
	mov al,0
	call PutBit
	mov ax,MatchLen
	dec ax
	dec ax
	push ax
	and al,2
	call PutBit
	pop ax
	and al,1
	call PutBit
	mov ax,MatchNpos
	call PutCh
	jmp L35
LA05:
	mov al,1
	call PutBit
	mov ax,MATCHNPOS
	call PutCh
	mov al,ah
	mov cl,3
	shl al,cl
	mov bx,MatchLen
	cmp bx,9
	ja LA10
	dec bx
	dec bx
	or al,bl
	call PutCh
	jmp L35
LA10:
	call PutCh
	mov ax,bx
	dec ax
	call PutCh
L35:
	mov ax,MATCHLEN

; pour l'‚cart entre les 2 codes
	sub ECART,ax
	jge L36
L37:
	inc ECARTMAX
	add ECART,16
	cmp ECART,0
	jl L37
L36:

; pour les segments
    add SEGSIZE,ax
	cmp SEGSIZE,0A000h
	jb L40
	mov al,0
	call PutBit
	mov al,1
	call PutBit
	mov al,00h
	call PutCh
	mov al,0F0h
	call PutCh
	mov al,1
	call PutCh
    mov SEGSIZE,0
L40:
	pop DI
	pop SI


; lecture des octets suivants
	mov es,SEGBUFIN
	jmp S3AA0
S3A9D:
	call INSERTNODE
S3AA0:
	call DELETENODE

S3ABA:
	dec BUFINSIZE
	jne S3ABB
	call GETBUF
	or ax,ax
	je S3ACE
	jmp S3ABA
S3ABB:
	mov bx,BUFINPTR
	inc BUFINPTR
	mov al,es:[BX]
	mov [SI+offset TBUF],AL
	cmp SI,LENMAX-1
	jnb S3ACC
	mov [SI+(offset TBUF)+BUFSIZE],AL
S3ACC:
	jmp S3AD2
S3ACE:
	dec LENREST
S3AD2:
	inc SI
	inc DI
	and SI,(BUFSIZE-1)
	and DI,(BUFSIZE-1)
	dec MATCHLEN
	jnz S3A9D
	call TESTMATCH
	cmp LENREST,0
	jle S3AEF
	jmp S3A55

S3AEF:

 mov al,0
 call PutBit
 mov al,1
 call PutBit
 mov al,00h
 call PutCh
 mov al,0F0h
 call PutCh
 mov al,0
 call PutCh

 call PutCodeBuf

	call CLOSEIO

 	pop bp
 	ret

LZCOMP endp


CODE ends

end


