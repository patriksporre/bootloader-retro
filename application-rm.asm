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

    call unchained_vga_mode

    ; Set up the grayscale palette
    call set_grayscale_palette

; Main rendering loop of our application
main:
    ;call unchained_vga_clear

    ; Clear back buffer
    ;call clear_back_buffer

    ; Render XOR pattern
    call render_xor_pattern

    ; Wait for VBlank
    call wait_for_vblank

    ; Flip the back buffer
    ;call flip_backbuffer
    call unchained_flip

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

unchained_vga_mode:
    ; Unchain the VGA memory
    mov dx, 0x03c4          ; Sequencer address register (0x03c4)
    mov al, 0x04            ; Memory mode index
    out dx, al              

    inc dx                  ; Sequence data register (0x03c5)
    in  al, dx              ; Read current memory settings
    and al, 11110111b       ; Disable the 4th bit (bit 3) to unchain VGA
    or  al, 00000100b       ; Enable the 3rd bit (bit 2) to disable the odd/even addressing scheme
    out dx, al              

    ; Set write mode 0 and disable odd/even addressing
    mov dx, 0x03ce          ; Graphics controller address register (0x03ce)
    mov al, 0x05            ; Graphics mode register index (index 5)
    out dx, al
    inc dx                  ; Graphics data register (0x03CF)
    in al, dx               ; Read current graphics mode
    and al, 11101100b       ; Clear bits 0, 1, and 4 to set write mode 0 and disable odd/even addressing
    out dx, al              ; Write updated value to graphics mode

    ; Disable chained mode in the graphics controller
    mov dx, 0x03ce          ; Graphics controller address register (0x03ce)
    mov al, 0x06            ; Miscellaneous graphics register index
    out dx, al

    inc dx                  ; Graphics controller data register (0x03cf)
    in  al, dx              ; Read current valu
    and al, 11011101b       ; Set the 6th (bit 5) to disable chain-4 mode, and the 2nd (bit 1) chain odd/even
    out dx, al

    ; Disable the doubleword mode for more granular control
    mov dx, 0x03d4          ; CRTC address register (0x03d4)
    mov al, 0x14            ; Index for the underline location register
    out dx, al              

    inc dx                  ; CRTC data register (0x03d5)
    in  al, dx              ; Read current underline location register value
    and al, 10111111b       ; Clear the 7th bit (bit 6) to disable doubleword addressing
    out dx, al              

    ; Disable word addressing to enable single byte access
    mov dx, 0x03d4          ; CRTC address register (0x03d4)
    mov al, 0x17            ; Mode control register
    out dx, al

    inc dx                  ; CRTC data register (0x03d5)
    in  al, dx              ; Read current mode control register value
    or  al, 01000000b       ; Set the 7th bit (bit 6) to 1 to disable word addressing
    out dx, al

    ; Set the logical screen width in bytes
    mov dx, 0x3d4           ; CRTC address register (0x03d4)
    mov al, 0x13            ; Logical screen width register
    out dx, al

    inc dx                  ; CRTC data register (0x03d5)
    mov al, WIDTH / 8       ; Plane width
    out dx, al

    ret



unchained_vga_clear:
    ; Set up the Map Mask register to select all planes
    mov dx, 0x03c4          ; VGA sequencer address register
    mov ax, 0x0F02          ; Select Map Mask register, enable all planes
    out dx, ax              ; Set all planes for simultaneous write

    ; Set up segment for video memory
    mov ax, 0xA000          ; VGA video memory segment
    mov es, ax

    ; Clear screen with the provided color
    xor di, di              ; Start at the beginning of VGA memory
    mov cx, 32000           ; Only 16,000 writes are needed for 320x200 pixels in Mode X
    mov ax, 0x0001
    rep stosb               ; Write color in AL across the screen

    ret






unchained_flip:
    ; Set up the back buffer segment
    mov ax, BUFFER_ADDR      ; Address of the back buffer
    mov ds, ax               ; Set DS to the back buffer segment

    ; Set up video memory segment
    mov ax, VIDEO_ADDR           ; VGA video memory segment
    mov es, ax               ; Set ES to the video memory segment

    ; Initialize index and loop counter
    xor di, di               ; Reset destination index (ES:DI)
    xor si, si               ; Reset source index (DS:SI)

    ; Loop through each plane
    mov cx, 16000            ; 320 * 200 / 4 = 16000 bytes per plane

    ; Plane 0
    mov dx, 0x03C4           ; VGA sequencer address register
    mov al, 0x02             ; Map Mask Register index
    out dx, al               ; Select Map Mask register
    inc dx                   ; Data register (0x03C5)
    mov al, 0x01             ; Plane 0 mask (00000001b)
    out dx, al               ; Set the plane mask
plane0_loop:
    mov al, [ds:si]          ; Load byte from back buffer
    mov [es:di], al          ; Write to video memory plane 0
    add si, 4                ; Move to the next pixel in the back buffer
    inc di                   ; Move to the next byte in video memory
    loop plane0_loop

    ; Plane 1
    mov si, 1                ; Start with offset 1 in the back buffer for plane 1
    mov di, 0                ; Reset destination index
    mov cx, 16000            ; Reset loop counter for plane 1
    mov al, 0x02             ; Plane 1 mask (00000010b)
    out dx, al               ; Set the plane mask
plane1_loop:
    mov al, [ds:si]          ; Load byte from back buffer
    mov [es:di], al          ; Write to video memory plane 1
    add si, 4                ; Move to the next pixel in the back buffer
    inc di                   ; Move to the next byte in video memory
    loop plane1_loop

    ; Plane 2
    mov si, 2                ; Start with offset 2 in the back buffer for plane 2
    mov di, 0                ; Reset destination index
    mov cx, 16000            ; Reset loop counter for plane 2
    mov al, 0x04             ; Plane 2 mask (00000100b)
    out dx, al               ; Set the plane mask
plane2_loop:
    mov al, [ds:si]          ; Load byte from back buffer
    mov [es:di], al          ; Write to video memory plane 2
    add si, 4                ; Move to the next pixel in the back buffer
    inc di                   ; Move to the next byte in video memory
    loop plane2_loop

    ; Plane 3
    mov si, 3                ; Start with offset 3 in the back buffer for plane 3
    mov di, 0                ; Reset destination index
    mov cx, 16000            ; Reset loop counter for plane 3
    mov al, 0x08             ; Plane 3 mask (00001000b)
    out dx, al               ; Set the plane mask
plane3_loop:
    mov al, [ds:si]          ; Load byte from back buffer
    mov [es:di], al          ; Write to video memory plane 3
    add si, 4                ; Move to the next pixel in the back buffer
    inc di                   ; Move to the next byte in video memory
    loop plane3_loop

    ret
