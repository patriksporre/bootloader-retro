
%define BOOT_ADDR   0x9000  ; This is where the boatloade puts the application

bits 16
org BOOT_ADDR

section .text               ; Code section

start:
%ifdef DEBUG
    ; Display 'A' for application stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'A'             
    int 0x10                ; Video BIOS services
%endif

    jmp $                   ; Infinite loop