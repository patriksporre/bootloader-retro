%define BOOT_ADDR   0x8000  ; This is where the boatloade puts the application
%define BUFFER_ADDR 0x9000  ; Destination address for the back buffer
%define VIDEO_ADDR  0xa000  ; Video memory address

%define VIDEO_MODE  0x13    ; 320x200 256 colors
%define WIDTH       320     ; Mode 13h width
%define HEIGHT      200     ; Mode 13h height

%define BACKGROUND  0       ; Background color (palette index)
%define COLOR       4       ; Color (palette index)

bits 16
org BOOT_ADDR

section .text               ; Code section
%ifdef DEBUG
    ; Add the bytes '1', '2', '3', and '4' at the beginning of the file
    db '1234'
%endif

start:
%ifdef DEBUG
    ; Display 'A' for application stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'A'             
    int 0x10                ; Video BIOS services
%endif

    ; Set video mode 13h (320x200 @ 256 colors)
    xor ax, ax              ; Set video mode
    mov al, VIDEO_MODE      ; Video mode
    int 0x10                ; Video BIOS services

    ; Set up the grayscale palette
    call set_grayscale_palette

; Main rendering loop of our application
main:
    ; Clear back buffer
    call clear_back_buffer

    ; Render XOR pattern
    call render_xor_pattern

    ; Wait for VBlank
    call wait_for_vblank

    ; Flip the back buffer
    call flip_backbuffer

    jmp main

; -------------- Functions --------------

; Function: set_grayscale_palette
; Description: Generates a grayscale palette
; Register used: AX, CX, DX
set_grayscale_palette:
    mov dx, 0x3c8           ; Set color index register
    xor ax, ax              ; Start at color index 0
    out dx, al              ; Write starting color index to 0x3c8

    inc dx                  ; Move to 0x3c9 (color data register)

    xor cx, cx
grayscale_palette:
    mov al, cl              ; Use color index as grayscale level (0 to 255)
    
    out dx, al              ; Set red component
    out dx, al              ; Set green component
    out dx, al              ; Set blue component

    inc cx                  ; Increment CX

    cmp cx, 256             ; Have we generated all 256 colors?
    jl  grayscale_palette   ; If not, jump to 'greyscale_palette'
    
    ret

; Function: clear_back_buffer
; Description: Clears the back buffer by filling it with the background color
; Registers used: AX, CX, DI, ES
clear_back_buffer:
    mov ax, BUFFER_ADDR     ; Set ES to back buffer
    mov es, ax              ; Set ES (extra segment) to BUFFER_ADDR

    xor di, di              ; Start at the beginning of the buffer
    mov al, BACKGROUND      ; AL holds the index to the color in the palette
    mov cx, WIDTH * HEIGHT  ; 
    rep stosb

    ret

; Function: render_xor_pattern
; Description: Renders an XOR pattern all over the back buffer
; Registers used: AX, BX, CX, DI, ES
render_xor_pattern:
    mov ax, BUFFER_ADDR     ; Set ES to back buffer
    mov es, ax
    
    xor di, di              ; Start at the beginning of the buffer
    xor cx, cx              ; CX will serve as the Y coordinate (0 to HEIGHT-1)

y_loop:
    xor bx, bx              ; BX will serve as the X coordinate (0 to WIDTH-1)

x_loop:
    mov al, cl              ; AL = Y (from CX)
    xor al, bl              ; AL = Y ^ X (CL ^ BL)

    stosb                   ; Store color (AL) at ES:DI, increment DI

    inc bx                  ; Move to the next X position
    cmp bx, WIDTH           ; Check if X < WIDTH
    jl x_loop               ; Loop if we haven't reached the end of the row

    inc cx                  ; Move to the next Y position
    cmp cx, HEIGHT          ; Check if Y < HEIGHT
    jl y_loop               ; Loop if we haven't reached the end of the screen

    ret

; Function: wait_for_vblank
; Description: Waits for vertical blank to prevent screen tearing
; Registers used: AX, DX
wait_for_vblank:
    mov dx, 0x03da          ; VGA status register
wait_vsync:
    in  al, dx              ; Read VGA status
    and al, 0x08            ; Mask to check the VBlank bit
    jz  wait_vsync          ; Wait until in VBlank
wait_not_vsync:
    in  al, dx              ; Read VGA status
    and al, 0x08            ; Mask to check the VBlank bit
    jnz wait_not_vsync      ; Wait until VBlank ends

    ret

; Function: flip_backbuffer
; Description: Copies back buffer to video memory
; Registers used: CX, DI, DS, ES, SI
flip_backbuffer:
    mov ax, BUFFER_ADDR     
    mov ds, ax              ; Set DS (data segment) to BUFFER_ADDR

    mov ax, VIDEO_ADDR
    mov es, ax              ; Set ES (extra segment) to VIDEO_ADDR

    xor si, si
    xor di, di
    mov cx, (WIDTH * HEIGHT) / 2
    rep movsw

    ret