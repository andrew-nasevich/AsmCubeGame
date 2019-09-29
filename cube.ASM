; di - screen
; si - array
macro push [arg] { push arg }
macro pop [arg] { pop arg }
;--------------------------------------------------------

org 100h

EscKey = 27
LeftKey = 75
RightKey = 77
UpKey = 72
DownKey = 80
SpaceKey = 32

PathColor = 15
SquerColor = $20
TrailColor = 40
WallColor = 125

Step = 10
Size = 10

ScreenWidth = 320
ScreenHight = 200

        push Random.wPrevNumber
        call  Random.Initialize
        push RightSize, OldVideoMod
        call initialization
        cmp byte[RightSize], 1
        jne @F
        push Field, Random.wPrevNumber
        call ChangeWholeArray
@@:
        call PrepareScreen
        mov [X], Size
        mov [Y], Size
GameCycle:
        push [X], [Y], SquerColor
        call DrawSquare

        call ReadKey

; check the end of the game
        cmp [X], ScreenWidth
        jne Left

        cmp [Y], ScreenHight
        je  EndGame
Left:
        push dx

        push [X], [Y], TrailColor
        call DrawSquare

        pop dx

        cmp dh, 00
        jz Zero
        cmp dh, LeftKey
        jnz Right
        mov ax, [X]

        sub ax, Step
        cmp ax, Size
        jl GameCycle

        push ax

        push Field
           sub ax, Size
        push Y
           inc ax
        push ax
        call CheckVerticalLine
        cmp ax, 0
        jnz @F
        pop ax
        jmp GameCycle
@@:
        pop ax
        mov [X], ax

        jmp GameCycle

Right:
        cmp dh, RightKey
        jnz Up
        mov ax, [X]
        add ax, Step

; 0 <= X <= RightBorder

        cmp ax, ScreenWidth
        ja GameCycle

        push ax

        push Field
        push Y
        push ax
        call CheckVerticalLine
        cmp ax, 0
        jnz @F
        pop ax
        jmp GameCycle
@@:
        pop ax
        mov [X], ax
        jmp GameCycle
Up:
        cmp dh, UpKey
        jnz Down
        mov ax, [Y]
        sub ax, Step
        cmp ax, Size
        jl GameCycle

        push ax

        push Field
           sub ax, Size
        push X
           inc ax
        push Y
        push ax
        call CheckHorizontalLine
        cmp ax, 0
        jnz @F
        pop ax
        jmp GameCycle
@@:
        pop ax
        mov [Y], ax

        jmp GameCycle

Down:
        cmp dh, DownKey
        jnz GameCycle
        mov ax, [Y]
        add ax, Step

; 0 <= Y <= BottomBorder
        mov dx, ScreenHight
        cmp ax, dx
        ja GameCycle
        push ax

        push Field, X, Y, ax
        call CheckHorizontalLine
        cmp ax, 0
        jnz @F
        pop ax
        jmp GameCycle
@@:
        pop ax
        mov [Y], ax

        jmp GameCycle
Zero:
        cmp dl, SpaceKey
        jnz .Esc
        cmp byte[RightSize], 1
        jne GameCycle
        push Field, Random.wPrevNumber
        call ChangeWholeArray
        call PrepareScreen

        jmp GameCycle
.Esc:
        cmp dl, EscKey
        jnz GameCycle
        mov [EscEnd], 1
EndGame:
        call finalization
        ret

; Returns in dx:
;   $00xx   For character keys
;   $xx00   For extended keys
ReadKey:
        xor dx, dx
        mov ax, 0C08h
        int 21h
        mov dl, al
        test al, al
        jnz .EndProc
        mov ah, $08
        int 21h
        mov dh, al
.EndProc:
        ret

; 1 - x
; 2 - y
; 3 - color
DrawSquare:
        push bp
        mov bp, sp
        mov al, [bp + 4]
        mov dx, [bp + 6]
        ;dec dx      dec и inc нужны, но они друг друга перекрывают
        sub dx, Size
        ;inc dx
        imul di, dx, ScreenWidth
        add di, [bp + 8]
        sub di, Size

        mov dx, Size
.Drawing:
        mov cx, Size
        rep  stosb
        sub di, Size
        add di, ScreenWidth
        dec dx
        jnz .Drawing

        pop bp
        ret 6

PrepareScreen:
        push di, si

        xor di, di
        xor si, si
.Cycle:
        mov cx, 8
        mov dl, [Field + si]
.ByteProcessing:
        rol dl, 1
        jc @F
        mov al, PathColor
        stosb
        loop .ByteProcessing
        inc si
        cmp si, 8000
        je .End
        jmp .Cycle
@@:
        mov al, WallColor
        stosb
        loop .ByteProcessing
        inc si
        cmp si, 8000
        je .End
        jmp .Cycle
.End:
        pop si, di
        ret

initialization:
        push bp
        mov bp, sp
        push bx
        mov ah, 0fh
        int 10h
        mov bx, [bp + 4]
        mov [bx], al

        mov ah, 00h
        mov al, 13h
        int 10h
        push $A000
        pop es


        mov bx , [bp + 6]
        mov ax, ScreenWidth
        mov dl, Size
        cmp dl, 1
        je .SizeIsOne
        div dl
        cmp ah, 0
        jnz @F
        mov ax, ScreenHight
        mov dl, Size
        div dl
        cmp ah, 0
        jnz @F
.SizeIsOne:
        inc byte[bx]

@@:
        pop bx, bp
        ret 4

finalization:
        mov al, [EscEnd]
        or al, al
        jnz .WithoutCongrStr

        mov ah, 00h
        mov al, 03h
        int 10h

        mov ah, 09h
        mov dx, FinalStr
        int 21h
        call ReadKey
.WithoutCongrStr:
        mov ah, 00h
        mov al, [OldVideoMod]
        int 10h
        ret

;[bp + 4] - addr PrevNumber, [bp + 6] - addr Field
;[bp - 2] - X, [bp - 4] - Y
ChangeWholeArray:
        push bp
        mov bp, sp
        sub sp, 4
        push bx
        mov word[bp - 2], 1
        mov word[bp - 4], 1
.Cycle:

        push word[bp + 4], 20, 0 ; границы увеличены, чтобы рандом работал. Если от 0 до 1, то результат будет чередоваться: 1 0 1 0 1 0 1
        call GetRandom
        cmp ax, 10
        ja @F
        xor ax,ax
        jmp .Draw
@@:
        mov ax, 1
.Draw:
        push word[bp + 6], ax , word[bp - 4], word[bp - 2]
        call ChangeSquare
        add word[bp - 2], Size
        cmp word[bp - 2], ScreenWidth
        ja .ChangeY
        jmp .Cycle

.ChangeY:
        add word[bp - 4], Size
        cmp word[bp - 4], ScreenHight
        ja .End
        mov word[bp - 2], 1
        jmp .Cycle

.End:
        mov ax, [Y]
        sub ax, Size
        inc ax
        mov dx, [X]
        sub dx, Size
        inc dx

        push word[bp + 6], 0 , ax, dx
        call ChangeSquare
        pop bx
        leave
        ret 4

;[bp + 4] -  X, [bp + 6] - Y, [bp + 8] - to fill with 0 or 1, [bp + 10] - addr Field
;[bp - 2] - кол-во проверяемых бит в байте, [bp - 4] - высота квадрата(кол-во линий), [bp - 6] - смещение для нахождения первого байта в линии (работает с Field), [bp - 8] - dx
ChangeSquare:
        push bp
        mov bp, sp
        sub sp, 8
        push si
        push bx
        mov word[bp - 4], Size
        mov ax, [bp + 6]
        dec ax
        imul ax, ScreenWidth
        xor dx, dx
        add ax, [bp + 4]
        mov cx, 8
        div cx
        cmp dx, 0
        jne @f
        mov dx, 8
        dec ax
@@:
        dec dx
        mov bx, [bp + 10]
        mov [bp - 6], ax
        mov [bp - 8], dx
.NewLine:
        mov cx, Size
        mov si, [bp - 6]

        mov dx, [bp - 8]
        mov word[bp - 2], 8   ; [bp - 2] -  кол-во изменяемых бит в первом байте
        sub [bp - 2], dx
        mov dx,[bp - 2]
        dec dx

        cmp cx, [bp - 2]
        ja .Enough
        mov [bp - 2], cx
        xor cx, cx
        jmp .FilingFirstByte
.Enough:
        sub cx, [bp - 2]

.FilingFirstByte:
        cmp word[bp + 8], 1
        je .FillWith1

.FillWith0:
        btr word[bx + si], dx
        dec dx
        dec word[bp - 2]
        jz .AnotherByte
        jmp .FillWith0

.FillWith1:

        bts word[bx + si], dx
        dec dx
        dec word[bp - 2]
        jz .AnotherByte
        jmp .FillWith1

.AnotherByte:
        jcxz .EndLine
        inc si
        mov dx, 8
        cmp cx, dx
        ja @F
        mov [bp - 2], cx
        xor cx, cx
        jmp .FilingAnotherByte
@@:
        mov [bp - 2], dx
        sub cx, dx
.FilingAnotherByte:
        dec dx
        cmp word[bp + 8], 1
        je .FillAnotherByteWith1

.FillAnotherByteWith0:
        btr [bx + si], dx
        dec dx
        dec word[bp - 2]
        jz .AnotherByte
        jmp .FillAnotherByteWith0

.FillAnotherByteWith1:
        bts [bx + si], dx
        dec dx
        dec word[bp - 2]
        jz .AnotherByte
        jmp .FillAnotherByteWith1

.EndLine:
        dec word[bp - 4]
        cmp word[bp - 4], 0
        jz .End
        add word[bp - 6], 40 ; 320 / 16 = 20
        jmp .NewLine
.End:
        pop bx
        pop si
        leave
        ret 8

;ax => 1 - withoutwall, ax => 0 - with wall
;[bp + 8] - addr Field, [bp + 6] - addr  Y, [bp + 4] - ax
CheckVerticalLine:
        push bp
        mov bp, sp
        push bx, si
        mov ax, [bp + 4]
        ;dec ax

        mov bh, 8
        div bh

        cmp ah, 0
        jnz .WithResidue
        mov ah, 8
        dec al
.WithResidue:
        mov bh, ah
        push bx
        mov bx, [bp + 6]
        mov si, [bx]
        pop bx
        ;dec si
        sub si, Size
        ;inc si

        imul si, 40
        movzx ax, al
        add si, ax
        mov bl, Size
.Label:
        push bx
        mov bx, [bp + 8]
        mov al, [bx + si]
        pop bx
        mov cl, bh
        rol al, cl
        jnc .Proceed
        xor ax, ax
        jmp .EndProc
.Proceed:
        add si, 40
        dec bl
        jnz .Label

        mov ax, 1
.EndProc:
        pop si, bx, bp
        ret 6

;ax => 1 - withoutwall, ax => 0 - with wall
;[bp + 10] - addr Field, [bp + 8] - addr X, [bp + 6] - addr  Y, [bp + 4] - ax
CheckHorizontalLine:

        push bp
        mov bp, sp
        push bx, si

        mov ax, [bp + 4]

        dec ax
        mov bl, Size
        imul ax, 40 ; 320 / 8 = 40
        mov si, ax
        push bx
        mov bx, [bp + 8]
        mov ax, [bx]
        pop bx
        sub ax, Size
        inc ax
        mov bh, 8

        div bh

        cmp ah, 0
        jnz  .WithResidue
        mov ah, 8
        dec al
.WithResidue:
        dec ah
        movzx dx, al
        add si, dx

        mov dl, 8
        sub dl, ah
        mov cl, ah
        movzx ax, bl
        div dl
        cmp al, 0
        jz .Next
        mov ah, dl
.Next:
        mov bh, ah

; bl - кол-во оставшихся проверяемых бит
; bh - кол-во проверяемых бит в данном байте
; cl - кол-во непроверяемых бит в данном байте
.Cycle1:
        push bx
        mov bx, [bp + 10]
        mov al, [bx + si]
        pop bx
        rol al, cl
        movzx cx, bh
.Cycle2:
        rol al, 1
        jnc .Proceed1
        xor ax, ax
        jmp .EndProc
.Proceed1:
        loop .Cycle2

        sub bl, bh
        jz  .EndCycle1

        movzx ax, bl
        mov dl, 8
        inc si
        xor cx, cx
        div dl
        cmp al, 0
        jz .Proceed2
        mov ah, 8
.Proceed2:
        mov bh, ah
        jmp .Cycle1
.EndCycle1:
        mov ax,1

.EndProc:

        pop si, bx, bp
        ret 8

include 'Random\Random.Procedures.txt'

FinalStr db 'Congrats, you won!',13,10,'Press any key$'
include 'Random\Random.Variables.txt'
OldVideoMod db ?
X dw Size
Y dw Size
; 320 * 200 / 8 = 8000
Field db 8000 dup 0
EscEnd db 0; 1 - y, 0 - n
RightSize db 0; 1 - y, 0 - n