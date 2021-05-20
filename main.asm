; ============================================================
; Flappy Bird
; ============================================================
; 11/05/2021 -> ??/??/2021
; TI501 - Linguagem de Montagem
; ============================================================
; 19164 Bruno Arnone Franchi
; 19188 Mateus Stolze Vazquez
; 19191 Nícolas Denadai Schmidt
; ============================================================

; == instruções para o masm32 ==
	.386
	.model flat, stdcall
	option casemap :none

; === includes e bibliotecas ===

	include \masm32\include\windows.inc
    include \masm32\macros\macros.asm
	include \masm32\include\masm32rt.inc
	include \masm32\include\msimg32.inc
	include \masm32\include\user32.inc

	includelib \masm32\lib\user32.lib
	includelib \masm32\lib\kernel32.lib
	includelib \masm32\lib\gdi32.lib
	includelib \masm32\lib\comctl32.lib
	includelib \masm32\lib\comdlg32.lib
	includelib \masm32\lib\shell32.lib
	includelib \masm32\lib\msimg32.lib
	includelib \masm32\lib\oleaut32.lib
	includelib \masm32\lib\msvcrt.lib
	includelib \masm32\lib\masm32.lib

; ========= prototypes =========
	WinMain			PROTO :DWORD,:DWORD,:DWORD,:DWORD
	WndProc			PROTO :DWORD,:DWORD,:DWORD,:DWORD
	TopXY			PROTO :DWORD,:DWORD

; ============================================================

.const
	WM_FINISH		equ	WM_USER+100h

	; ======= recursos (.rc) =======

	ICON			equ 500
	sprites			equ	107

	; ======== crop do bmp =========

	; fundo
	cropBgW			equ	331			; largura
	cropBgH			equ 589 		; altura

	; pássaro
	cropBirdX		equ	607			; x origem
	cropBirdY		equ	147 		; y origem
	cropBirdW		equ	38			; largura
	cropBirdH		equ	27			; altura

	; cano de cima
	cropCanoCX		equ	691			; x origem
	cropCanoCY		equ	0			; y origem
	cropCanoCW		equ	63			; largura
	cropCanoCH		equ	310			; altura

	; cano de baixo
	cropCanoBX		equ	759			; x origem
	cropCanoBY		equ	0			; y origem
	cropCanoBW		equ	63			; largura
	cropCanoBH		equ	277			; altura

	; =========== física ===========

	birdMaxVel		equ 20			; velocidade vertical máxima
	flapForce		equ -13			; forca vertical por clique

	; ====== margens e offsets =====

	margemEsq		equ -70
	margemDir		equ cropBgW + 165
	offsetCanoY		equ 500
	canoCBaseY		equ -300
	canoBBaseY		equ 150

	; =========== outros ===========

	CREF_TRANSPARENT equ 0082597Bh			; cor de fundo a ser filtrada

.data
	; ====== variaveis da tela ======
	szDisplayName	db "Flappy Bird",0 		; titulo da janela
	CommandLine		dd 0
	hWnd			dd 0
	hInstance		dd 0

	; ======= posicao pássaro =======
	birdX			dd 140					; x do pássaro
	birdY			dd 200					; y do pássaro

	; ======== posicao canos ========
	cano1X			dd cropBgW
	cano1Y			dd 100
	cano2X			dd margemDir + 120
	cano2Y			dd 100

	; ======== velocidade ========
	birdVelocity	dd 0 					; velocidade do pássaro
	pipeVelocity	dd 10 					; velocidade do cano

.data?
	threadID		DWORD ?
	hEventStart		HANDLE ?
	hBmpSprites		dd ?

; ============================================================

.code

start:
	invoke	GetModuleHandle, NULL
	mov		hInstance, eax

	invoke	GetCommandLine
	mov		CommandLine, eax

	; carregar bitmap
	invoke	LoadBitmap, hInstance, sprites
	mov		hBmpSprites, eax

	; carregar janela
	invoke	WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT

	; finalizar processo
	invoke	ExitProcess,eax

; ============================================================

WinMain proc hInst	:DWORD,
					hPrevInst :DWORD,
					CmdLine   :DWORD,
					CmdShow   :DWORD

	; == colocar valores na stack ==

	LOCAL wc		:WNDCLASSEX
	LOCAL msg		:MSG

	LOCAL WWidth	:DWORD
	LOCAL WHeigth	:DWORD
	LOCAL Wtx		:DWORD
	LOCAL Wty		:DWORD

	szText szClassName, "flappybird_asm"

	; ==== variáveis da janela =====

	mov wc.cbSize,         sizeof WNDCLASSEX
	mov wc.style,          CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
	mov wc.lpfnWndProc,    offset WndProc      	; address of WndProc
	mov wc.cbClsExtra,     NULL
	mov wc.cbWndExtra,     NULL
	m2m wc.hInstance,      hInst               	; instance handle
	mov wc.hbrBackground,  COLOR_BTNFACE+1    	; system color
	mov wc.lpszMenuName,   NULL
	mov wc.lpszClassName,  offset szClassName  	; window class name
	invoke LoadIcon,hInst,ICON
	mov wc.hIcon,          eax
		invoke LoadCursor,NULL,IDC_ARROW        ; system cursor
	mov wc.hCursor,        eax
	mov wc.hIconSm,        0

	invoke RegisterClassEx, ADDR wc     		; registrando a classe da janela

	mov WWidth, cropBgW 						; largura da janela (window width)
	mov WHeigth, cropBgH 						; altura da janela (window height)

	invoke GetSystemMetrics,SM_CXSCREEN 		; get screen width in pixels
	invoke TopXY,WWidth,eax
	mov Wtx, eax

	invoke GetSystemMetrics,SM_CYSCREEN 		; get screen height in pixels
	invoke TopXY,WHeigth,eax
	mov Wty, eax

	; ======= criar a janela =======

	invoke CreateWindowEx,	WS_EX_OVERLAPPEDWINDOW,
							ADDR szClassName,
							ADDR szDisplayName,
							WS_OVERLAPPEDWINDOW, ;CS_HREDRAW,
							Wtx,Wty,WWidth,WHeigth,
							NULL,NULL,
							hInst,NULL

	mov   hWnd,eax  							; copy return value into handle DWORD

	invoke LoadMenu,hInst,600                 	; load resource menu
	invoke SetMenu,hWnd,eax                   	; set it to main window

	invoke ShowWindow,hWnd,SW_SHOWNORMAL      	; display the window
	invoke UpdateWindow,hWnd                  	; update the display

	; == loop até PostQuitMessage ==

	StartLoop:
		invoke GetMessage,ADDR msg,NULL,0,0     ; get each message
		cmp eax, 0                              ; exit if GetMessage()
		je ExitLoop                             ; returns zero
		invoke TranslateMessage, ADDR msg       ; translate it
		invoke DispatchMessage,  ADDR msg       ; send it to message proc
		jmp StartLoop
	ExitLoop:

		return msg.wParam

WinMain endp

; ============================================================

WndProc proc hWin	:DWORD,
					uMsg   :DWORD,
					wParam :DWORD,
					lParam :DWORD

	LOCAL hDC    :DWORD
	LOCAL Ps     :PAINTSTRUCT
	LOCAL rect   :RECT
	LOCAL Font   :DWORD
	LOCAL Font2  :DWORD
	LOCAL hOld   :DWORD

	LOCAL memDC  :DWORD

	; ====== comandos de menu ======
	.if uMsg == WM_COMMAND

		.if wParam == 1000
			invoke SendMessage,hWin,WM_SYSCOMMAND,SC_CLOSE,NULL

		.elseif wParam == 1001
			mov eax, offset ThreadProc
			invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR threadID
		.endif
	; ==== fim comandos de menu ====

	; ===== entrada de teclado =====
	.elseif uMsg == WM_CHAR ; caso seja um caracter

	.elseif uMsg == WM_KEYDOWN 					; caso seja uma chave
		.if wParam == VK_UP 					; seta para cima
			mov ebx, 40000000h
			and ebx, lParam						; verificar se a tecla foi pressionada nesse tick
			jnz nao_bater						; se não, está sendo segurada. ignorar comando
			mov birdVelocity, flapForce			; bater as asas
			nao_bater:
		.endif
	; === fim entrada de teclado ===

	.elseif uMsg == WM_FINISH
		mov rect.left, 100
		mov	rect.top , 100
		mov	rect.right, 32
		mov	rect.bottom, 32
		invoke InvalidateRect, hWnd, NULL, TRUE ;addr rect, TRUE

	.elseif uMsg == WM_PAINT

		; iniciar seção de desenhar sprites
		invoke BeginPaint,hWin,ADDR Ps
		mov    hDC, eax

		; desenhar fundo
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke BitBlt, hDC, 0,0,cropBgW,cropBgH, memDC, 0,0, SRCCOPY
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC

		; desenhar bird
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke TransparentBlt, hDC,	birdX, birdY, cropBirdW, cropBirdH, memDC, cropBirdX, cropBirdY, cropBirdW, cropBirdH, CREF_TRANSPARENT
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC

		; =========== cano 1 ===========
		; checar se está dentro da tela
		mov ebx, cano1X
		cmp ebx, margemDir
		jg chk_c2
		cmp ebx, margemEsq
		jl chk_c2

		; se sim, desenhar suas partes
		; cima
		mov ebx, cano1Y
		add ebx, canoCBaseY
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke TransparentBlt, hDC,	cano1X, ebx, cropCanoCW, cropCanoCH, memDC, cropCanoCX, cropCanoCY, cropCanoCW, cropCanoCH, CREF_TRANSPARENT
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC
		; baixo
		mov ebx, cano1Y
		add ebx, canoBBaseY
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke TransparentBlt, hDC,	cano1X, ebx, cropCanoBW, cropCanoBH, memDC, cropCanoBX, cropCanoBY, cropCanoBW, cropCanoBH, CREF_TRANSPARENT
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC

		; =========== cano 2 ===========
		chk_c2:
		; checar se está dentro da tela
		mov ebx, cano2X
		cmp ebx, margemDir
		jg fim_canos
		cmp ebx, margemEsq
		jl fim_canos

		; se sim, desenhar suas partes
		; cima
		mov ebx, cano2Y
		add ebx, canoCBaseY
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke TransparentBlt, hDC,	cano2X, ebx, cropCanoCW, cropCanoCH, memDC, cropCanoCX, cropCanoCY, cropCanoCW, cropCanoCH, CREF_TRANSPARENT
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC
		; baixo
		mov ebx, cano2Y
		add ebx, canoBBaseY
		invoke CreateCompatibleDC, hDC
		mov   memDC, eax
		invoke SelectObject, memDC, hBmpSprites
		mov  hOld, eax
		invoke TransparentBlt, hDC,	cano2X, ebx, cropCanoBW, cropCanoBH, memDC, cropCanoBX, cropCanoBY, cropCanoBW, cropCanoBH, CREF_TRANSPARENT
		invoke SelectObject,hDC,hOld
		invoke DeleteDC,memDC
		fim_canos:

		; finalizar seção de desenhar sprites
		invoke EndPaint,hWin,ADDR Ps
		return  0
	.elseif uMsg == WM_CREATE
	; --------------------------------------------------------------------
	; This message is sent to WndProc during the CreateWindowEx function
	; call and is processed before it returns. This is used as a position
	; to start other items such as controls. IMPORTANT, the handle for the
	; CreateWindowEx call in the WinMain does not yet exist so the HANDLE
	; passed to the WndProc [ hWin ] must be used here for any controls
	; or child windows.
	; --------------------------------------------------------------------
		invoke  CreateEvent, NULL, FALSE, FALSE, NULL
		mov     hEventStart, eax

		mov eax, offset ThreadProc
		invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR threadID

	.elseif uMsg == WM_CLOSE
	.elseif uMsg == WM_DESTROY
	; ----------------------------------------------------------------
	; This message MUST be processed to cleanly exit the application.
	; Calling the PostQuitMessage() function makes the GetMessage()
	; function in the WinMain() main loop return ZERO which exits the
	; application correctly. If this message is not processed properly
	; the window disappears but the code is left in memory.
	; ----------------------------------------------------------------
			invoke PostQuitMessage,NULL
			return 0
	.endif
	invoke DefWindowProc,hWin,uMsg,wParam,lParam
	; --------------------------------------------------------------------
	; Default window processing is done by the operating system for any
	; message that is not processed by the application in the WndProc
	; procedure. If the application requires other than default processing
	; it executes the code when the message is trapped and returns ZERO
	; to exit the WndProc procedure before the default window processing
	; occurs with the call to DefWindowProc().
	; --------------------------------------------------------------------
	ret
WndProc endp

; ============================================================

TopXY proc wDim:DWORD, sDim:DWORD

	; ----------------------------------------------------
	; This procedure calculates the top X & Y co-ordinates
	; for the CreateWindowEx call in the WinMain procedure
	; ----------------------------------------------------
	shr sDim, 1      ; divide screen dimension by 2
	shr wDim, 1      ; divide window dimension by 2
	mov eax, wDim    ; copy window dimension into eax
	sub sDim, eax    ; sub half win dimension from half screen dimension
	return sDim
TopXY endp

; ============================================================

; Essa eh a proc que criamos para influenciar a velocidade que o passaro cai
; Caso o passaro caia de forma linear, ele se tornara previsivel e o jogo nao tera graca
; Criamos uma aceleracao para que o passaro nao caia de forma linear e se torne previsivel
; eh claro, caso a aceleracao influencie a velocidade de forma infinita, nao sera possivel jogar
; assim, vamos atribuir uma velocidade maxima que o passaro possa atingir
GravidadeProc proc
	mov eax, birdMaxVel 	; criamos uma velocidade maxima que o passaro pode atingir
	mov ebx, birdVelocity 	; colocamos em ebx a velocidade atual do passaro
	cmp eax, ebx 			; comparamos a velocidade maxima que o passaro pode atingir com a velocidade atual dele
	jl	a
	add birdVelocity, 1
	a:
	add birdY, ebx
	ret
GravidadeProc endp

Colisao proc
	mov birdY, 1000
	ret
Colisao endp

; comparamos se ele esta na area do cano em termos de x
; depois, comparamos se ele colidiu em termos de y
CheckColisao proc
	; para detectar colisões, definimos uma
	; caixa de colisão determinada pelos 4
	; pontos extremos dos sprites. depois,
	; fazemos verificações para determinar
	; se há intersecções. cada bloco descreve
	; os pontos utilizados e a verificação
	; sendo feita, cada ponto tem 2 valores
	; qual um ja foi verificado ou eh irrelevante
	; para o momento

	; P(W,_) e C(0,_)
	; se está à esquerda
	mov eax, cano1X
	mov ebx, birdX
	add ebx, cropBirdW
	cmp ebx, eax
	jle	col_c2

	; P(0,_), C(W,_)
	; se está à direita
	mov eax, cano1X
	add eax, cropCanoCW
	mov ebx, birdX
	cmp ebx, eax
	jge	col_c2

	; P(_,0), C(_,H)
	; se está em baixo
	mov eax, cano1Y
	add eax, canoCBaseY
	add eax, cropCanoCH
	mov ebx, birdY
	cmp ebx, eax
	jge	col_c2

	; P(_,H), B(_,0)
	; se está acima
	mov eax, cano1Y
	add eax, canoBBaseY
	mov ebx, birdY
	add ebx, cropBirdY
	cmp ebx, eax
	jle	col_c2
	invoke Colisao

	; cano 2
	col_c2:
	; P(W,_) e C(0,_)
	; se está à esquerda
	mov eax, cano2X
	mov ebx, birdX
	add ebx, cropBirdW
	cmp ebx, eax
	jle	fim_colisao

	; P(0,_), C(W,_)
	; se está à direita
	mov eax, cano2X
	mov ebx, birdX
	add eax, cropCanoCW
	cmp ebx, eax
	jge	fim_colisao

	; P(_,0), C(_,H)
	; se está em baixo
	mov eax, cano2Y
	add eax, canoCBaseY
	add eax, cropCanoCH
	mov ebx, birdY
	cmp ebx, eax
	jge	fim_colisao

	; P(_,H), B(_,0)
	; se está acima
	mov eax, cano2Y
	add eax, canoBBaseY
	mov ebx, birdY
	add ebx, cropBirdY
	cmp ebx, eax
	jle	fim_colisao
	invoke Colisao

	fim_colisao:
	ret
CheckColisao endp

; ============================================================

; proc para spawnar canos
; sempre que um cano sai da tela pela esquerda,
; ele é recolocado fora da tela na direita
;
Spawnar proc
	mov eax, cano1X
	cmp eax, margemEsq 		; se o cano 1 estiver fora da tela
	jg cano2
	mov eax, margemDir		; resetá-lo para a direita da tela
	mov cano1X, eax

	cano2:
	mov eax, cano2X
	cmp eax, margemEsq		; se o cano 2 estiver fora da tela
	jg spawn_ret
	mov eax, margemDir		; resetá-lo para a direita da tela
	mov cano2X, eax

	spawn_ret:
	ret
Spawnar endp


; proc responsavel por mover os canos pela tela

MoverPilares proc
	mov eax, pipeVelocity
	sub cano1X, eax
	sub cano2X, eax
	ret
MoverPilares endp
; ============================================================

ThreadProc proc uses eax Param:DWORD
	invoke WaitForSingleObject, hEventStart, 33 ; depois de quantos milisegundos iremos aplicar uma mudanca
	.if eax == WAIT_TIMEOUT
		; lógica do jogo
		invoke GravidadeProc
		invoke CheckColisao
		invoke Spawnar
		invoke MoverPilares
		; invocar atualização de tela
		invoke SendMessage, hWnd, WM_FINISH, NULL, NULL
	.endif
	jmp  ThreadProc
	ret
ThreadProc endp

; ============================================================

end start

; Fazer as colisões
; Fazer telas de Game Over e Início
; Guardar a pontuação
; rng de altura dos canos
