
%define BOOT_ADDR   0x7c00  ; This is where BIOS loads the bootloader
%define LOAD_ADDR   0x8000  ; Destination address in memory for the application
%define SECTORS     0x01    ; # sectors to read

; Our memory is mapped with the following approach:
;   0x7c00 - 0x7fff: Our bootloader (1024 bytes)
;   0x8000 - 0x8fff: Our application code (4096 bytes)
;   0x9000 - 0x9fff: Our back buffer
;   0xa000 - 0xafff: Video memory 

bits 16
org BOOT_ADDR

section .text               ; Code section

start:
    mov [bootdrive], dl     ; Store the boot drive number from BIOS

    ; Setup segments and stack
    cli                     ; Disable interrupts
    xor ax, ax              ; Zero out AX
    mov ds, ax              ; Set DS (data segment) to 0x0000
    mov es, ax              ; Set ES (extra segment) to 0x0000
    mov ss, ax              ; Set SS (stack segment) to 0x0000
    mov sp, 0x7c00          ; Set SP (stack pointer) to 0x7c00 (stack grows downwards)
    sti                     ; Enable interrupts

%ifdef DEBUG
    ; Display 'L' for loading stage
    mov ah, 0x0e            ; Teletype output
    mov al, 'L'             
    int 0x10                ; Video BIOS services
%endif

    ; Load the application from disk starting at sector 2 (1-based indexing)
    mov ch, 0x00            ; Cylinder number
    mov cl, 0x02            ; Sector number (1-based indexing)
    mov dh, 0x00            ; Head number
    mov dl, [bootdrive]     ; Boot drive number (passed by BIOS)
    mov bx, LOAD_ADDR       ; Destination address in memory for the load

    mov si, 3               ; BIOS disk read shall be given three attempts

retry:
    mov ah, 0x02            ; Read disk sectors
    mov al, SECTORS         ; Number of sectors to read
    int 0x13                ; Disk BIOS services

    jnc disksuccess         ; Jump to 'success' if no reading error

    dec si                  ; Decrement retry counter
    jz  error               ; Jump to 'diskerror' if no more retries

    mov ah, 0x00            ; Reset disk system
    int 0x13                ; Disk BIOS services

    jmp retry               ; Jump to 'retry'

disksuccess:
%ifdef DEBUG
    ; Display 'S' for loading success
    mov ah, 0x0e            ; Teletype output
    mov al, 'S'             
    int 0x10                ; Video BIOS services
%endif

%ifdef DEBUG
    ; To check if we have loaded the data correctly we read and display the first four bytes of the application
    mov si, LOAD_ADDR       ; Destination address in memory for the load
    mov cx, 4               ; Four bytes
print:
    mov al, [si]            ; load byte into al
    mov ah, 0x0e            ; Teletype output
    int 0x10                ; Video BIOS services

    inc si                  ; Next byte
    loop print              ; Jump to 'print' label if more bytes to print
%endif

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