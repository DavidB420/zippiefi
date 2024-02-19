;ZippiEFI
;Copyright (C) 2024 David Badiei
format pe64 efi
entry main

section '.text' executable readable

include 'uefi.inc'

main:
;Save EFI system table that is loaded into rdx
mov qword [efiSystemTable],rdx
mov qword [efiImageHandle],rcx
;Query text mode
call getTextMode
;Output welcome message
mov rsi,welcomeStr
mov rbx,0
call centeredPrintString
cli
jmp $
;Begin to load the file system
call initEfiFileSystem
call openFile
ret

;getTextMode
getTextMode:
;Read mode number
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.Mode]
mov eax,[rax+4]
push rax
;Get rows and columns
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.QueryMode]
pop rdx
lea r8,[textColumns]
lea r9,[textRows]
sub rsp,32
call rax
add rsp,32
ret

;numToString
;IN: r8 = number
numToString:
push rax
push rbx
push rcx
push rdx
push rdi
;Clear number buffer
mov rcx,5
mov eax,0
mov rdi,numberBuffer
repe stosd
;Convert each digit to ASCII then save it into stack
xchg rax,r8
mov rcx,0
loopSaveNumberStack:
mov rdx,0
mov rbx,10
div rbx
add dl,30h
push dx
inc rcx
test rax,rax
jnz loopSaveNumberStack
;Save number into buffer
mov rdi,numberBuffer
loopSaveNumberBuffer:
pop ax
stosb
inc rdi
loop loopSaveNumberBuffer
pop rdi
pop rdx
pop rcx
pop rbx
pop rax
ret

initEfiFileSystem:
;Get loaded image pointer
mov rcx,[efiImageHandle]
mov rdx,EFI_LOADED_IMAGE_PROTOCOL_GUID
lea r8,[efiLoadedImage]
mov r9,qword [efiSystemTable]
mov r9,[r9+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [r9+EFI_BOOT_SERVICES_TABLE.HandleProtocol]
add rsp,32
;Get volume handle
mov rcx,[efiLoadedImage]
mov rcx,[rcx+EFI_LOADED_IMAGE_PROTOCOL.DeviceHandle]
mov rdx,EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID
lea r8,[efiVolumeHandle]
mov r9,qword [efiSystemTable]
mov r9,[r9+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [r9+EFI_BOOT_SERVICES_TABLE.HandleProtocol]
add rsp,32
;Open Volume
mov rcx,[efiVolumeHandle]
lea rdx,[efiRootFSHandle]
sub rsp,32
call qword [rcx+EFI_SIMPLE_FILE_SYSTEM_PROTOCOL.OpenVolume]
add rsp,32
ret

openFile:
;Open file and check if file loaded successfully
mov rcx,[efiRootFSHandle]
lea rdx,[efiFileHandle]
mov r9,EFI_FILE_MODE_READ
sub rsp,32
call qword [rcx+EFI_FILE_PROTOCOL.Open]
add rsp,32
cmp rax,0
je skiperrorloadingkernel
sub rsp,8
mov rsi,errorStr
call printString
add rsp,8
call waitForAnyKey
call resetPC
skiperrorloadingkernel:
;Get file size
mov rcx,[efiFileHandle]
mov rdx,EFI_FILE_INFO_ID_GUID
lea r8,[efiFileInfoBufferSize]
mov r9,efiFileInfoBuffer
sub rsp,40
call qword [rcx+EFI_FILE_PROTOCOL.GetInfo]
add rsp,40
mov r9,[efiFileInfoBuffer+8]
mov qword [efiReadSize],r9
;Allocate memory pool
mov rcx,2
mov rdx,qword [efiReadSize]
lea r8,[efiOSBufferHandle]
mov r9,qword [efiSystemTable]
mov r9,[r9+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [r9+EFI_BOOT_SERVICES_TABLE.AllocatePool]
add rsp,32
;Read file
mov rcx,[efiFileHandle]
lea rdx,[efiReadSize]
mov r8,[efiOSBufferHandle]
sub rsp,32
call qword [rcx+EFI_FILE_PROTOCOL.Read]
add rsp,32
ret

;waitForAnyKey
waitForAnyKey:
;Reset keyboard hardware
mov rdx,1
mov rcx,[efiSystemTable]
mov rcx,[rcx+EFI_SYSTEM_TABLE.ConIn]
sub rsp,32
call qword [rcx+EFI_SIMPLE_TEXT_INPUT_PROTOCOL.Reset]
add rsp,32
;Poll until the key is read
loopwaitforkeypress:
lea rdx,[efiKeyData]
mov rcx,[efiSystemTable]
mov rcx,[rcx+EFI_SYSTEM_TABLE.ConIn]
sub rsp,32
call qword [rcx+EFI_SIMPLE_TEXT_INPUT_PROTOCOL.ReadKeyStroke]
add rsp,32
and rax,0xff
cmp rax,6 ;Check if its not ready
je loopwaitforkeypress
ret

;resetPC
resetPC:
;Reset using 8042 method (if possible)
mov al,0xfe
out 0x64,al
;Reset using UEFI runtime services
mov rax,qword [efiSystemTable]
mov rax,[rax+EFI_SYSTEM_TABLE.RuntimeServices]
mov rax,[rax+EFI_RUNTIME_SERVICES_TABLE.ResetSystem]
mov r9d,0
mov r8d,0
mov edx,0
mov ecx,0
call rax
ret

;setCursorPos
;IN: RAX = column position, RBX = row position
setCursorPos:
push rax
push rbx
push rcx
push rdx
push r8
;Save row and column into proper argument registers
push rbx
push rax
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.SetCursorPosition]
pop rdx
pop r8
;Setup shadow space for GPRs
sub rsp,32
call rax
add rsp,32
pop r8
pop rdx
pop rcx
pop rbx
pop rax
ret

;centeredPrintString
;IN: RSI = string pointer, RBX = Row to display string on
centeredPrintString:
push rax
push rcx
;Calculate and set starting point so string is at the center
mov rax,[textColumns]
shr rax,1
call getUnicodeStringLength
shr rcx,1
sub rax,rcx
call setCursorPos
;Display string using the regular function
call printString
pop rcx
pop rax
ret

;getUnicodeStringLength
;IN: RSI = string pointer
;OUT: RCX = length of string
getUnicodeStringLength:
push rax
push rsi
;Character is word lengthed, keep counting until 0x0000
mov rcx,0
loopReadStringValues:
lodsw
test ax,ax
jz gotStringLength
inc rcx
jmp loopReadStringValues
gotStringLength:
pop rax
pop rsi
ret

;printString
;IN: RSI = string pointer
printString:
push rdx
push rcx
push rax
push rsi
;Get ConOut in rcx, then use that to get the pointer for the OutputString function in rax 
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.OutputString]
xchg rdx,rsi
;Setup shadow space for GPRs
sub rsp,32
call rax
add rsp,32
pop rsi
pop rax
pop rcx
pop rdx
ret

section '.data' readable writable

welcomeStr du 'ZippiEFI', 0xD, 0xA, 'Copyright (C) 2024 David Badiei', 0xD, 0xA, 'Please select an option from below', 0
errorStr du 'Error loading CONFIG.JSON!', 0xd, 0xa, 'Press any key to reboot...',0
efiSystemTable dq 0
efiLoadedImage dq 0
efiImageHandle dq 0
efiDevicePathHandle dq 0
efiVolumeHandle dq 0
efiRootFSHandle dq 0
efiFileHandle dq 0
efiOSBufferHandle dq 0
efiReadSize dq 1216
efiKeyData dq 0
efiFileInfo dq 0
textRows dq 0
textColumns dq 0
currentHighestRes dq 0
currentHighestIndex db 0
frameBufferPPS dd 0
EFI_LOADED_IMAGE_PROTOCOL_GUID db 0xa1, 0x31, 0x1b, 0x5b, 0x62, 0x95, 0xd2, 0x11, 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID db 0x22, 0x5b, 0x4e, 0x96, 0x59, 0x64, 0xd2, 0x11, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_FILE_INFO_ID_GUID db 0x92, 0x6e, 0x57, 0x09, 0x3f, 0x6d, 0xd2, 0x11, 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b
efiFileInfoBufferSize dq 128
efiFileInfoBuffer: times 128 db 0
numberBuffer: times 21 db 0
blockiouuid db EFI_BLOCK_IO_PROTOCOL_UUID
gopguid db EFI_GRAPHICS_OUTPUT_PROTOCOL_UUID
EFI_FILE_MODE_READ = 0x0000000000000001
