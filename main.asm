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
	include \masm32\include\masm32rt.inc
	include \masm32\include\msimg32.inc

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
	WinMain		PROTO :DWORD,:DWORD,:DWORD,:DWORD
	WndProc		PROTO :DWORD,:DWORD,:DWORD,:DWORD
	TopXY		PROTO :DWORD,:DWORD

; ============================================================

.const
	ICONE	equ     500
	WM_FINISH equ WM_USER+100h

	sprites	equ		107

	cropBgW	equ		331
	cropBgH	equ		589

	cropBirdX	equ	607 ; Cordenada x inicio da sprite do passaro 
	cropBirdY	equ	147 ; Cordenada y inicio da sprite do passaro
	cropBirdW	equ	38 ; largura da sprite do passaro (width)
	cropBirdH	equ	27 ; altura da sprite do passaro (height)

	birdMaxVel	equ 20 ; essa e a velocidade maxima que o passaro pode atingir (em pixels pelo eixo y)
	flapForce	equ -13 ; a forca que ele vai para cima por clique

	CREF_TRANSPARENT  equ 0082597Bh ; Isso filtra as cores de uma imagem

.data
	szDisplayName	db "Flappy Bird",0 ; esse sera o titulo da janela
	CommandLine		dd 0
	hWnd			dd 0
	hInstance		dd 0
	buffer			db 128 dup(0)
	birdX			dd 140 ; essa variavel sera utilizada para determinar a posicao do nosso passaro
	birdY			dd 200 ;  essa variavel sera utilizada para determinar a posicao do nosso passaro
	birdVelocity	dd 0
	msg1			db "Mandou uma mensagem Ok",0
	contador		dd 0 ;
	imgY			dd 100 ; so precisamos do y por que o passaro nao sai do lugar, o cenario se move para tras mas ele nao percorre o eixo x

.data?
	hitpoint	POINT <>
	hitpointEnd	POINT <>
	threadID	DWORD ?
	hEventStart	HANDLE ?
	hBmpSprites	dd ?

; ============================================================

.code

start:
	invoke	GetModuleHandle, NULL
	mov		hInstance, eax

	invoke	GetCommandLine
	mov		CommandLine, eax

	; ====== carregar bitmaps ======
	invoke	LoadBitmap, hInstance, sprites
	mov		hBmpSprites, eax
	; ==============================

	invoke	WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT	; carregar janela

	invoke	ExitProcess,eax	; finalizar processo

; ============================================================

WinMain proc hInst	:DWORD,
					hPrevInst :DWORD,
					CmdLine   :DWORD,
					CmdShow   :DWORD

	;====================
	; Put LOCALs on stack
	;====================

	LOCAL wc   :WNDCLASSEX
	LOCAL msg  :MSG

	LOCAL WWidth  :DWORD
	LOCAL WHeigth  :DWORD
	LOCAL Wtx  :DWORD
	LOCAL Wty  :DWORD

	szText szClassName,"Generic_Class"

	;==================================================
	; Fill WNDCLASSEX structure with required variables
	;==================================================

	mov wc.cbSize,         sizeof WNDCLASSEX
	mov wc.style,          CS_HREDRAW or CS_VREDRAW \
													or CS_BYTEALIGNWINDOW
	mov wc.lpfnWndProc,    offset WndProc      ; address of WndProc
	mov wc.cbClsExtra,     NULL
	mov wc.cbWndExtra,     NULL
	m2m wc.hInstance,      hInst               ; instance handle
	mov wc.hbrBackground,  COLOR_BTNFACE+1     ; system color
	mov wc.lpszMenuName,   NULL
	mov wc.lpszClassName,  offset szClassName  ; window class name
	; id do icon no arquivo RC
	invoke LoadIcon,hInst,500                  ; icon ID   ; resource icon
	mov wc.hIcon,          eax
		invoke LoadCursor,NULL,IDC_ARROW         ; system cursor
	mov wc.hCursor,        eax
	mov wc.hIconSm,        0

	invoke RegisterClassEx, ADDR wc     ; registrando a classe da janela

	;================================
	; Centre window at following size
	;================================

	mov WWidth, cropBgW ; largura da janela (windows width)
	mov WHeigth, cropBgH ; altura da janela (windows height)

	invoke GetSystemMetrics,SM_CXSCREEN ; get screen width in pixels
	invoke TopXY,WWidth,eax
	mov Wtx, eax

	invoke GetSystemMetrics,SM_CYSCREEN ; get screen height in pixels
	invoke TopXY,WHeigth,eax
	mov Wty, eax

	; ==================================
	; Create the main application window
	; ==================================
	invoke CreateWindowEx,	WS_EX_OVERLAPPEDWINDOW,
							ADDR szClassName,
							ADDR szDisplayName,
							CS_HREDRAW,
							Wtx,Wty,WWidth,WHeigth,
							NULL,NULL,
							hInst,NULL

	mov   hWnd,eax  ; copy return value into handle DWORD

	invoke LoadMenu,hInst,600                 ; load resource menu
	invoke SetMenu,hWnd,eax                   ; set it to main window

	invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; display the window
	invoke UpdateWindow,hWnd                  ; update the display

	;===================================
	; Loop until PostQuitMessage is sent
	;===================================

	StartLoop:
		invoke GetMessage,ADDR msg,NULL,0,0         ; get each message
		cmp eax, 0                                  ; exit if GetMessage()
		je ExitLoop                                 ; returns zero
		invoke TranslateMessage, ADDR msg           ; translate it
		invoke DispatchMessage,  ADDR msg           ; send it to message proc
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
			invoke CreateThread,	NULL, NULL, eax,  \
									NULL, NORMAL_PRIORITY_CLASS, \
									ADDR threadID
			mov     contador, 0

		.elseif wParam == 1900
			szText TheMsg,"Assembler, Pure & Simple"
			invoke MessageBox,hWin,ADDR TheMsg,ADDR szDisplayName,MB_OK

		.endif
	; ==== fim comandos de menu ====

	; ===== entrada de teclado =====
	.elseif uMsg == WM_CHAR ;caso seja um caracter
		invoke wsprintf,addr buffer,chr$("LETRA =  %c"), wParam
		invoke MessageBox,hWin,ADDR buffer,ADDR szDisplayName,MB_OK

	.elseif uMsg == WM_KEYDOWN ; caso seja uma chave
		.if wParam == VK_UP ; seta para cima
			; verificar se a tecla foi pressionada nesse tick
			mov ebx, 40000000h
			and ebx, lParam
			; se não, está sendo segurada. ignorar comando
			jnz ignorar
			mov birdVelocity, flapForce	; bater as asas
			ignorar:
		.endif
	; === fim entrada de teclado ===

	.elseif uMsg == WM_FINISH
		mov   rect.left, 100
		mov   rect.top , 100
		mov   rect.right, 32
		mov   rect.bottom, 32
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
		mov     imgY,250
		invoke  CreateEvent, NULL, FALSE, FALSE, NULL
		mov     hEventStart, eax

		mov eax, offset ThreadProc
		invoke CreateThread, NULL, NULL, eax,  \
															NULL, NORMAL_PRIORITY_CLASS, \
															ADDR threadID
		mov     contador, 0

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
	mov eax, birdMaxVel ; criamos uma velocidade maxima que o passaro pode atingir
	mov ebx, birdVelocity ; colocamos em ebx a velocidade atual do passaro
	cmp eax, ebx ; comparamos a velocidade maxima que o passaro pode atingir com a velocidade atual dele
	jl	a
	add birdVelocity, 1
	a:
	add birdY, ebx
	ret
GravidadeProc endp
; ============================================================
ThreadProc proc uses eax Param:DWORD
	invoke WaitForSingleObject, hEventStart, 33 ; depois de quantos milisegundos iremos aplicar uma mudanca
	.if eax == WAIT_TIMEOUT
		; lógica do jogo
		inc  contador
		invoke GravidadeProc
		; invocar atualização de tela
		invoke SendMessage, hWnd, WM_FINISH, NULL, NULL
	.endif
	jmp  ThreadProc
	ret
ThreadProc endp
end start
