
%define BOOT_ADDR   0x7c00  ; This is where BIOS loads the bootloader
%define LOAD_ADDR   0x9000  ; Destination address in memory for the application
%define SECTORS     0x01    ; # sectors to read

bits 16
org BOOT_ADDR

section .text               ; Code section

start:
    mov [bootdrive], dl     ; Store the boot drive number from BIOS

%ifdef DEBUG
    ; Display 'L' for loading stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'L'             
    int 0x10                ; Video BIOS services
%endif

    ; Load the application from disk starting at sector 2 (1-based indexing)
    mov ah, 0x02            ; Read disk sectors
    mov al, SECTORS         ; Number of sectors to read
    mov ch, 0x00            ; Cylinder number
    mov cl, 0x02            ; Sector number (1-based indexing)
    mov dh, 0x00            ; Head number
    mov dl, [bootdrive]     ; Boot drive number (passed by BIOS)
    mov bx, LOAD_ADDR       ; Destination address in memory for the load
    int 0x13                ; Disk BIOS services

    jc  error               ; Jump to 'error' if reading failed

%ifdef DEBUG
    ; Display 'J' for jumping stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'J'             
    int 0x10                ; Video BIOS services
%endif

    ; Far jump to application loaded at LOAD_ADDR
    jmp 0x0000:LOAD_ADDR

error:
%ifdef DEBUG
    ; Display 'E' for error stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'E'             
    int 0x10                ; Video BIOS services
%endif

    hlt

; Boot sector padding and signature
    times 510-($-$$) db 0   ; Pad the boot sector to 510 bytes
    dw 0xaa55               ; Boot sector signature (0xaa55), required for a bootable sector

section .data               ; Data section

    bootdrive db 0          ; Variable to store boot drive number