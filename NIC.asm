;MODE=32
.MODEL FLAT, C
.386
.STACK 100h

.DATA
Packet_Data       dq 0,0                ; 8 bytes
Packet_Protocol   dd 0,0                ; 8 bytes reserved
Packet_ID         db 0
Packet_IP         dw 0

COM1_PORT   EQU 03F8h
UART_LSR    EQU COM1_PORT+5
THR_EMPTY   EQU 20h
DATA_READY  EQU 01h

.BSS
server  RESB 15
client  RESB 15
esi     RESD 1         ; general purpose index

.CODE
_start PROC

DriverLoop:
    cmp ah, 0
    je SEND
    cmp ah, 1
    je RECEIVE
    cmp ah, 2
    je FETCH
    jmp DriverLoop

;----------------------
SEND:
    mov esi, 0
send_loop:
    cmp esi, 15
    jge DriverLoop
    mov eax, DWORD PTR [client + esi]  ; try to send 4 bytes at a time
    ; send first byte
    mov al, al
wait_thr_send1:
    in al, UART_LSR
    test al, THR_EMPTY
    jz wait_thr_send1
    mov al, [client + esi]
    out COM1_PORT, al
    ; send second byte
    mov al, ah
wait_thr_send2:
    in al, UART_LSR
    test al, THR_EMPTY
    jz wait_thr_send2
    mov al, [client + esi + 1]
    out COM1_PORT, al
    ; send third byte
    mov al, byte ptr [client + esi + 2]
wait_thr_send3:
    in al, UART_LSR
    test al, THR_EMPTY
    jz wait_thr_send3
    out COM1_PORT, al
    ; send fourth byte
    mov al, byte ptr [client + esi + 3]
wait_thr_send4:
    in al, UART_LSR
    test al, THR_EMPTY
    jz wait_thr_send4
    out COM1_PORT, al

    add esi, 4
    jmp send_loop

;----------------------
RECEIVE:
    mov esi, 0
receive_loop:
    cmp esi, 15
    jge parse_packet
receive_wait:
    in al, UART_LSR
    test al, DATA_READY
    jz receive_wait
    in al, COM1_PORT
    mov [server + esi], al
    add esi, 1
    jmp receive_loop

;----------------------
parse_packet:
    mov esi, 0
    ; copy 8 bytes → Packet_Data using dwords
    mov eax, DWORD PTR [server]
    mov DWORD PTR [Packet_Data], eax
    mov eax, DWORD PTR [server + 4]
    mov DWORD PTR [Packet_Data + 4], eax

    ; copy 4 bytes → Packet_Protocol
    mov eax, DWORD PTR [server + 8]
    mov DWORD PTR [Packet_Protocol], eax

    ; Packet_ID
    mov al, [server + 12]
    inc byte ptr [Packet_ID]

    ; Packet_IP
    mov ax, [server + 13]
    mov [Packet_IP], ax

    jmp DriverLoop

;----------------------
FETCH:   ; AH = 02
    mov ebx, DWORD PTR [Packet_Data]       ; first 4 bytes
    mov edx, DWORD PTR [Packet_Data + 4]   ; next 4 bytes
    jmp DriverLoop

_start ENDP
END _start
