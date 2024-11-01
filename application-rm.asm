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

    ; Configure VGA for unchained mode
    call unchained_vga_mode

    ; Set up the grayscale palette
    call set_grayscale_palette

; Main rendering loop of our application
main:
    ; Clear the video memory in unchained mode
    ; call unchained_vga_clear

    ; Clear back buffer
    ; call clear_back_buffer

    ; Render XOR pattern to back buffer
    call render_xor_pattern

    ; Wait for VBlank
    call wait_for_vblank

    ; Flip the back buffer in linear mode
    ; call flip_backbuffer
    
    ; Flip the back buffer in unchained mode
    call unchained_flip

    jmp main

; -------------- Functions --------------

; Function: set_grayscale_palette
; Description: Generates a grayscale palette in 256 colors
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
; Description: Clears the back buffer with the background color
clear_back_buffer:
    mov ax, BUFFER_ADDR     
    mov es, ax              ; Set ES (extra segment) to BUFFER_ADDR

    xor di, di              ; Start at the beginning of the buffer
    mov al, BACKGROUND      ; AL holds the index to the color in the palette
    mov cx, WIDTH * HEIGHT  
    rep stosb

    ret

; Function: render_xor_pattern
; Description: RRenders an XOR pattern to the back buffer for visual testing
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
; Description: Waits for the start and end of the vertical blanking interval
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

; Function: unchained_vga_mode
; Description: Configures VGA to unchained mode for planar graphics
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

; Function: unchained_vga_clear
; Description: Clears all four VGA planes in unchained mode
unchained_vga_clear:
    ; Set up the map mask register to select all planes
    mov dx, 03c4h           ; Sequencer address register (0x03c4)
    mov al, 0x02            ; Set map mask register index (0x02)
    out dx, al              

    inc dx                  ; Sequence data register (0x03c5)
    mov al, 00001111b       ; Enable all planes by setting bits 0-3
    out dx, al            

    mov ax, VIDEO_ADDR      ; Set ES (extra segment) to VIDEO_ADDR
    mov es, ax

    mov al, 0x01            ; Set color to palette color 1
    xor di, di              ; Start from top left corner
    mov cx, 16000           ; Write 16000 bytes
paint:
    mov byte [es:di], al
    inc di
    loop paint

    ret

; Function: unchained_flip
; Description: Copies the back buffer to video memory in planar mode
unchained_flip:
    mov ax, BUFFER_ADDR      
    mov ds, ax              ; Set DS to the back buffer segment

    mov ax, VIDEO_ADDR       
    mov es, ax              ; Set ES to the video memory segment

    ; Set up the map mask register
    mov dx, 0x03c4          ; Sequencer address register (0x03c4)
    mov al, 0x02            ; Set map mask register index (0x02)
    out dx, al               

    inc dx                  ; Sequence data register (0x03c5)

    ; Initialize plane loop
    xor cx, cx              ; Start plane counter (CX = 0)
    
plane_copy_loop:
    ; Set plane mask by shifting '1' left by 'CL' (plane number)
    mov al, 0x01
    shl al, cl              ; Set the mask for the current plane (1, 2, 4, 8)
    out dx, al              ; Apply the plane mask

    ; Set 'SI' to the start of the correct plane in the back buffer
    mov si, cx              ; Offset by plane (CX = plane index)
    xor di, di              ; Reset destination index for each plane

    ; Copy 16000 bytes for the current plane
    mov bx, 16000           ; Set BX to copy 16000 bytes
    
plane_copy_pixels:
    mov al, [ds:si]         ; Load byte from back buffer
    mov [es:di], al         ; Write to video memory plane
    add si, 4               ; Skip four wo pixels in the back buffer
    inc di                  ; Advance by one byte in video memory

    dec bx                  ; Decrement bx counter
    jnz plane_copy_pixels   ; Repeat until 16000 bytes are copied

    inc cl                  ; Increment plane counter
    cmp cl, 4               ; Check if all 4 planes are done
    jl  plane_copy_loop     ; Repeat until all planes are copied

    ret