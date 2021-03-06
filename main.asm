; ============================================================
; Flappy Bird
; ============================================================
; 11/05/2021 -> 27/05/2021
; TI501 - Linguagem de Montagem
; ============================================================
; 19164 Bruno Arnone Franchi
; 19188 Mateus Stolze Vazquez
; 19191 Nícolas Denadai Schmidt
; ============================================================

; == instruções para o masm32 ==
	;.386
	;.model flat, stdcall
	;option casemap :none

; === includes e bibliotecas ===
	include \masm32\include\masm32rt.inc
	include \masm32\include\msimg32.inc
	include \masm32\include\cryptdll.inc
	include \masm32\include\winmm.inc

	includelib \masm32\lib\cryptdll.lib
	includelib \masm32\lib\kernel32.lib
	includelib \masm32\lib\gdi32.lib
	includelib \masm32\lib\comctl32.lib
	includelib \masm32\lib\comdlg32.lib
	includelib \masm32\lib\shell32.lib
	includelib \masm32\lib\msimg32.lib
	includelib \masm32\lib\oleaut32.lib
	includelib \masm32\lib\msvcrt.lib
	includelib \masm32\lib\masm32.lib
	includelib \masm32\lib\user32.lib
	includelib \masm32\lib\winmm.lib

; ========= prototypes =========
	WinMain			PROTO :DWORD,:DWORD,:DWORD,:DWORD
	WndProc			PROTO :DWORD,:DWORD,:DWORD,:DWORD
	;PlaySoundA		PROTO, pszSound:PTR BYTE, hmod:DWORD, fdwSound:DWORD
	TopXY			PROTO :DWORD,:DWORD
	GetLocalTime	PROTO :DWORD

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
	flapForce		equ -15			; forca vertical por clique

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
	colisao			dd 0

	; ======== posicao canos ========
	cano1X			dd cropBgW
	cano1Y			dd 100
	cano2X			dd margemDir + 120
	cano2Y			dd 100

	; === posicoes virtual canos ===

	cano1VirtYC		dd 0
	cano1VirtYB		dd 0
	cano2VirtYC		dd 0
	cano2VirtYB		dd 0

	; ======== velocidade ========
	birdVelocity	dd 0 					; velocidade do pássaro
	pipeVelocity	dd 6 					; velocidade do cano

	pontuacao		dd 0
	stringPontos	byte "   "
	; ======= música e sons ========
	musBfg			byte "bfg_division.wav",0

	sfxFlap			byte "sfx_flap.wav",0
	sfxCoin			byte "sfx_coin.wav",0

	; =========== lógica ===========
	gameState		dd 0					; 0 título; 1 em jogo; 2 game over

	; ============ prng ============
	seed			dd 0
	prngAtual		dd 0

	; outros
	buffer			db 128 dup(0)

.data?
	threadID		DWORD ?
	hEventStart		HANDLE ?
	hBmpSprites		dd ?
	LPSYSTEMTIME STRUCT
    	wYear       WORD ?
    	wMonth      WORD ?
    	wDayOfWeek  WORD ?
    	wDay        WORD ?
    	wHour       WORD ?
    	wMinute     WORD ?
    	wSecond     WORD ?
    	wMilliseconds WORD ?
	LPSYSTEMTIME ENDS
	localTime LPSYSTEMTIME <>

; ============================================================

.code

PRNG proc
	mov eax, 7
	mov ebx, prngAtual
	mul ebx
	add eax, 3
	mov prngAtual, eax
	ret
PRNG endp

; ============================================================

start:
	; gerar seed do prng
	; para isso, usamos o tempo atual do computador,
	; e usamos o valor de milissegundos+1 para a seed
	; com isso, garantimos uma seed entre 1 e 1000
	invoke GetLocalTime, ADDR localTime
	movzx eax, localTime.wMilliseconds
	add eax, 1
	mov seed, eax
	mov prngAtual, eax

	invoke PRNG
	movzx ecx, al
	add ecx, 80
	mov cano1Y, ecx

	invoke PRNG
	movzx ecx, al
	add ecx, 80
	mov cano2Y, ecx

	; handles
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

	LOCAL hDC		:DWORD
	LOCAL Ps		:PAINTSTRUCT
	LOCAL hPen		:DWORD
	LOCAL hOldPen	:DWORD
	LOCAL rect		:RECT
	LOCAL Font		:DWORD
	LOCAL hOld		:DWORD

	LOCAL memDC  :DWORD

	; ====== comandos de menu ======
	.if uMsg == WM_COMMAND

		.if wParam == 1000
			invoke SendMessage,hWin,WM_SYSCOMMAND,SC_CLOSE,NULL
		.elseif wParam == 1900
			invoke wsprintf,addr buffer,chr$("Flappy Bird",13,10,"em MASM assembly",13,10,"por:",13,10,"19164 - Bruno Arnone Franchi,",13,10,"19188 - Mateus Stolze Vazquez,",13,10,"19191 - Nicolas Denadai Schmidt",13,10,"25/05/2021")
            invoke MessageBox,hWin,ADDR buffer,ADDR szDisplayName,MB_OK
		.endif
	; ==== fim comandos de menu ====

	.elseif uMsg == WM_KEYDOWN 					; tecla foi pressionada
		.if wParam == VK_UP 					; seta para cima
			mov eax, gameState
			cmp eax, 1
			jne nao_em_jogo
			mov ebx, 40000000h
			and ebx, lParam						; verificar se a tecla foi pressionada nesse frame
			jnz nao_bater						; se não, está sendo segurada. ignorar comando
			mov birdVelocity, flapForce			; bater as asas
			invoke PlaySoundA, offset sfxFlap, NULL, SND_ASYNC
			nao_bater:
			jmp fim_teclas

			nao_em_jogo:
			mov birdVelocity, 0
			mov birdY, 200
			mov eax, cropBgW
			mov cano1X, eax
			mov eax, margemDir
			add eax, 120
			mov cano2X, eax
			mov pontuacao, 0
			mov gameState, 1

			fim_teclas:
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

		mov ebx, gameState

		.if ebx == 0		; titulo
			invoke GetClientRect, hWnd, addr rect
			mov   rect.left, 0
			mov   rect.top , 0
			mov   rect.right, cropBgW - 10
			mov   rect.bottom, 100
			invoke CreateFont, 48, 24, NULL, NULL, 300,FALSE,NULL,NULL, \
						DEFAULT_CHARSET,OUT_TT_PRECIS,CLIP_DEFAULT_PRECIS, \
						PROOF_QUALITY,DEFAULT_PITCH or FF_DONTCARE, \
						SADD("flappybird_font")
			mov Font, eax
			invoke SelectObject, hDC,Font
			mov   hOld, eax
			invoke SetBkMode, hDC, TRANSPARENT
			invoke SetTextColor,hDC,00ffffffh
			szText txtTitulo, "Flappy Bird"
			invoke DrawText, hDC, addr txtTitulo, -1, addr rect, DT_SINGLELINE or DT_CENTER or DT_VCENTER
		.elseif ebx == 1	; em jogo
			; desenhar bird
			invoke CreateCompatibleDC, hDC
			mov   memDC, eax
			invoke SelectObject, memDC, hBmpSprites
			mov  hOld, eax
			invoke TransparentBlt, hDC,	birdX, birdY, cropBirdW, cropBirdH, memDC, cropBirdX, cropBirdY, cropBirdW, cropBirdH, CREF_TRANSPARENT
			invoke SelectObject,hDC,hOld
			invoke DeleteDC,memDC

			; =========== cano 1 ===========
			; cima
			mov ebx, cano1Y
			add ebx, canoCBaseY
			mov cano1VirtYC, ebx
			invoke CreateCompatibleDC, hDC
			mov   memDC, eax
			invoke SelectObject, memDC, hBmpSprites
			mov  hOld, eax
			invoke TransparentBlt, hDC,	cano1X, cano1VirtYC, cropCanoCW, cropCanoCH, memDC, cropCanoCX, cropCanoCY, cropCanoCW, cropCanoCH, CREF_TRANSPARENT
			invoke SelectObject,hDC,hOld
			invoke DeleteDC,memDC
			; baixo
			mov ebx, cano1Y
			add ebx, canoBBaseY
			mov cano1VirtYB, ebx
			invoke CreateCompatibleDC, hDC
			mov   memDC, eax
			invoke SelectObject, memDC, hBmpSprites
			mov  hOld, eax
			invoke TransparentBlt, hDC,	cano1X, cano1VirtYB, cropCanoBW, cropCanoBH, memDC, cropCanoBX, cropCanoBY, cropCanoBW, cropCanoBH, CREF_TRANSPARENT
			invoke SelectObject,hDC,hOld
			invoke DeleteDC,memDC

			; =========== cano 2 ===========
			; cima
			mov ebx, cano2Y
			add ebx, canoCBaseY
			mov cano2VirtYC, ebx
			invoke CreateCompatibleDC, hDC
			mov   memDC, eax
			invoke SelectObject, memDC, hBmpSprites
			mov  hOld, eax
			invoke TransparentBlt, hDC,	cano2X, cano2VirtYC, cropCanoCW, cropCanoCH, memDC, cropCanoCX, cropCanoCY, cropCanoCW, cropCanoCH, CREF_TRANSPARENT
			invoke SelectObject,hDC,hOld
			invoke DeleteDC,memDC
			; baixo
			mov ebx, cano2Y
			add ebx, canoBBaseY
			mov cano2VirtYB, ebx
			invoke CreateCompatibleDC, hDC
			mov   memDC, eax
			invoke SelectObject, memDC, hBmpSprites
			mov  hOld, eax
			invoke TransparentBlt, hDC,	cano2X, cano2VirtYB, cropCanoBW, cropCanoBH, memDC, cropCanoBX, cropCanoBY, cropCanoBW, cropCanoBH, CREF_TRANSPARENT
			invoke SelectObject,hDC,hOld
			invoke DeleteDC,memDC
			fim_canos:

			; ========= pontuacao ==========
			invoke GetClientRect, hWnd, addr rect
			mov   rect.left, 0
			mov   rect.top , 0
			mov   rect.right, cropBgW - 10
			mov   rect.bottom, 100
			invoke CreateFont, 48, 24, NULL, NULL, 300,FALSE,NULL,NULL, \
						DEFAULT_CHARSET,OUT_TT_PRECIS,CLIP_DEFAULT_PRECIS, \
						PROOF_QUALITY,DEFAULT_PITCH or FF_DONTCARE, \
						SADD("flappybird_font")
			mov Font, eax
			invoke SelectObject, hDC,Font
			mov   hOld, eax
			invoke SetBkMode, hDC, TRANSPARENT
			invoke SetTextColor,hDC,00ffffffh
			invoke wsprintf,addr buffer, chr$("%d"), pontuacao
			invoke DrawText, hDC, addr buffer, -1, addr rect, DT_SINGLELINE or DT_CENTER or DT_VCENTER

			; ; =========== debug ============
			; invoke CreatePen, PS_SOLID, 4, Blue
			; mov hPen, eax

			; ; cano 1 cima
			; invoke SelectObject, hDC, hPen
			; mov eax, hOldPen
			; mov ebx, cano1X
			; add ebx, cropCanoCW
			; mov ecx, cano1VirtYC
			; add ecx, cropCanoCH
			; invoke Rectangle, hDC, cano1X, cano1VirtYC, ebx, ecx
			; invoke SelectObject, hDC, hOldPen

			; ; cano 1 baixo
			; invoke SelectObject, hDC, hPen
			; mov eax, hOldPen
			; mov ebx, cano1X
			; add ebx, cropCanoBW
			; mov ecx, cano1VirtYB
			; add ecx, cropCanoBH
			; invoke Rectangle, hDC, cano1X, cano1VirtYB, ebx, ecx
			; invoke SelectObject, hDC, hOldPen

			; invoke CreatePen, PS_SOLID, 4, Yellow
			; mov hPen, eax

			; ; cano 2 cima
			; invoke SelectObject, hDC, hPen
			; mov eax, hOldPen
			; mov ebx, cano2X
			; add ebx, cropCanoCW
			; mov ecx, cano2VirtYC
			; add ecx, cropCanoCH
			; invoke Rectangle, hDC, cano2X, cano2VirtYC, ebx, ecx
			; invoke SelectObject, hDC, hOldPen

			; ; cano 2 baixo
			; invoke SelectObject, hDC, hPen
			; mov eax, hOldPen
			; mov ebx, cano2X
			; add ebx, cropCanoBW
			; mov ecx, cano2VirtYB
			; add ecx, cropCanoBH
			; invoke Rectangle, hDC, cano2X, cano2VirtYB, ebx, ecx
			; invoke SelectObject, hDC, hOldPen

			; ; pássaro
			; cmp colisao, 0
			; jnz tem_colisao
			; invoke CreatePen, PS_SOLID, 4, Green
			; jmp cont_pen
			; tem_colisao:
			; invoke CreatePen, PS_SOLID, 4, Red
			; cont_pen:
			; mov hPen, eax

			; invoke SelectObject, hDC, hPen
			; mov eax, hOldPen
			; mov ebx, birdX
			; add ebx, cropBirdW
			; mov ecx, birdY
			; add ecx, cropBirdH
			; invoke Rectangle, hDC, birdX, birdY, ebx, ecx
			; invoke SelectObject, hDC, hOldPen
		.elseif ebx == 2	; game over
			invoke GetClientRect, hWnd, addr rect
			mov   rect.left, 0
			mov   rect.top , 0
			mov   rect.right, cropBgW - 10
			mov   rect.bottom, 100
			invoke CreateFont, 48, 24, NULL, NULL, 300,FALSE,NULL,NULL, \
						DEFAULT_CHARSET,OUT_TT_PRECIS,CLIP_DEFAULT_PRECIS, \
						PROOF_QUALITY,DEFAULT_PITCH or FF_DONTCARE, \
						SADD("flappybird_font")
			mov Font, eax
			invoke SelectObject, hDC,Font
			mov   hOld, eax
			invoke SetBkMode, hDC, TRANSPARENT
			invoke SetTextColor,hDC,00ffffffh
			invoke wsprintf,addr buffer, chr$("score: %d"), pontuacao
			invoke DrawText, hDC, addr buffer, -1, addr rect, DT_SINGLELINE or DT_CENTER or DT_VCENTER
		.endif

		invoke EndPaint,hWin,ADDR Ps
		return  0
	.elseif uMsg == WM_CREATE
		invoke  CreateEvent, NULL, FALSE, FALSE, NULL
		mov     hEventStart, eax

		mov eax, offset ThreadProc
		invoke CreateThread, NULL, NULL, eax, NULL, NORMAL_PRIORITY_CLASS, ADDR threadID
	.elseif uMsg == WM_CLOSE
	.elseif uMsg == WM_DESTROY
		invoke PostQuitMessage,NULL
		return 0
	.endif
	invoke DefWindowProc,hWin,uMsg,wParam,lParam
	ret
WndProc endp

; ============================================================

TopXY proc wDim:DWORD, sDim:DWORD
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
	; se o pássaro não atingiu velocidade máxima
	mov eax, birdMaxVel
	mov ebx, birdVelocity
	cmp eax, ebx
	jl	a
	add birdVelocity, 2	; continuar acelerando
	a:
	add birdY, ebx
	ret
GravidadeProc endp

Colisao proc
	;mov colisao, 1 ; debug
	mov gameState, 2
	ret
Colisao endp

; comparamos se ele esta na area do cano em termos de x
; depois, comparamos se ele colidiu em termos de y
CheckColisao proc
	mov colisao, 0

	; _X = _X0 + _W
	; _Y = _Y0 + _H

	; PX0 = birdX
	; PY0 = birdY
	; PX = birdX + cropBirdW
	; PY = birdY + cropBirdH

	; QX0 = canoX
	; QX = canoX + cropCanoX
	; CY0 = canoVirtYC
	; CY = canoVirtYC + cropCanoCH

	; PX < Q1X0 -> x não contém (sem colisão)
	; pássaro ainda não chegou no cano
	mov eax, birdX
	add eax, cropBirdW
	mov ebx, cano1X
	cmp eax, ebx
	jl	checar_cano2

	; PX0 > Q1X -> x não contém (sem colisão)
	; pássaro já passou do cano
	mov eax, birdX
	mov ebx, cano1X
	add ebx, cropCanoCW
	cmp eax, ebx
	jge	checar_cano2

	; PY0 > C1Y -> (sem colisão ACIMA)
	; pássaro está abaixo do cano de cima
	mov eax, birdY
	mov ebx, cano1VirtYC
	add ebx, cropCanoCH
	cmp eax, ebx
	jl	colisao_cano1

	; PY < B1Y0 -> (sem colisão ABAIXO)
	; pássaro está acima do cano de baixo
	mov eax, birdY
	add eax, cropBirdH
	mov ebx, cano1VirtYB
	cmp eax, ebx
	jl	checar_cano2

	colisao_cano1:
	invoke Colisao
	jmp fim_colisao

	checar_cano2:
	; PX < Q2X0 -> x não contém (sem colisão)
	; pássaro ainda não chegou no cano
	mov eax, birdX
	add eax, cropBirdW
	mov ebx, cano2X
	cmp eax, ebx
	jl	fim_colisao

	; PX0 > Q2X -> x não contém (sem colisão)
	; pássaro já passou do cano
	mov eax, birdX
	mov ebx, cano2X
	add ebx, cropCanoCW
	cmp eax, ebx
	jge	fim_colisao

	; PY0 > C2Y -> (sem colisão ACIMA)
	; pássaro está abaixo do cano de cima
	mov eax, birdY
	mov ebx, cano2VirtYC
	add ebx, cropCanoCH
	cmp eax, ebx
	jl	colisao_cano2

	; PY < B2Y0 -> (sem colisão ABAIXO)
	; pássaro está acima do cano de baixo
	mov eax, birdY
	add eax, cropBirdH
	mov ebx, cano2VirtYB
	cmp eax, ebx
	jl	fim_colisao

	colisao_cano2:
	invoke Colisao
	jmp fim_colisao

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
	invoke PRNG
	movzx ecx, al
	add ecx, 80
	mov cano1Y, ecx
	inc pontuacao			; dar um ponto ao jogador
	invoke PlaySoundA, offset sfxCoin, NULL, SND_ASYNC

	cano2:
	mov eax, cano2X
	cmp eax, margemEsq		; se o cano 2 estiver fora da tela
	jg spawn_ret
	mov eax, margemDir		; resetá-lo para a direita da tela
	mov cano2X, eax
	invoke PRNG
	movzx ecx, al
	add ecx, 80
	mov cano2Y, ecx
	inc pontuacao			; dar um ponto ao jogador
	invoke PlaySoundA, offset sfxCoin, NULL, SND_ASYNC

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
	invoke WaitForSingleObject, hEventStart, 33 ; 1s / 30fps = 33,3ms / frame
	.if eax == WAIT_TIMEOUT

		mov eax, gameState
		.if eax == 0
			; tela de inicio
		.elseif eax == 1
			; lógica do jogo
			invoke GravidadeProc
			invoke CheckColisao
			invoke Spawnar
			invoke MoverPilares
		.elseif eax == 2
			; game over
		.endif

		; invocar atualização de tela
		invoke SendMessage, hWnd, WM_FINISH, NULL, NULL
	.endif
	jmp  ThreadProc
	ret
ThreadProc endp

; ============================================================

end start
