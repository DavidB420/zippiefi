;ZippiEFI
;Main
;Copyright (C) 2024 David Badiei

format pe64 efi
entry main

section '.text' executable readable

include 'uefi.inc'
include 'displaystring.asm'
include 'json.asm'

main:
;Save EFI system table that is loaded into rdx
mov qword [efiSystemTable],rdx
mov qword [efiImageHandle],rcx
;Query text mode
call getTextMode
;Load config file
call initEfiFileSystem
mov r8,configFN
call openFile
;Output welcome message
mov rsi,welcomeStr
mov rbx,0
call centeredPrintString
;load efi options and highlight first item
mov rax,4
call loadEfiOptions
add byte [numOfItems],3
;Wait for user input
mov rax,4
loopUserInput:
push rax
call waitForAnyKey
pop rax
cmp qword [efiKeyData],1
jne skipgoup
cmp rax,4
jle loopUserInput
dec rax
jmp updateListHighlight
skipgoup:
cmp qword [efiKeyData],2
jne loopUserInput
mov bl,byte [numOfItems]
and rbx,0xff
cmp rax,rbx
jge loopUserInput
inc rax
updateListHighlight:
push rax
call loadEfiOptions
pop rax
jmp loopUserInput
cli
jmp $
ret

;initEfiFileSystem
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

;openFile
openFile:
;Open file and check if file loaded successfully
mov rcx,[efiRootFSHandle]
lea rdx,[efiFileHandle]
mov r9,EFI_FILE_MODE_READ
sub rsp,32
call qword [rcx+EFI_FILE_PROTOCOL.Open]
add rsp,32
cmp rax,0
je skiperrorloadingfile
sub rsp,8
mov rsi,errorLoadingStr
call printString
mov rsi,rebootStr
call printString
add rsp,8
call waitForAnyKey
call resetPC
skiperrorloadingfile:
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
lea r8,[efiFileBufferHandle]
mov r9,qword [efiSystemTable]
mov r9,[r9+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [r9+EFI_BOOT_SERVICES_TABLE.AllocatePool]
add rsp,32
;Read file
mov rcx,[efiFileHandle]
lea rdx,[efiReadSize]
mov r8,[efiFileBufferHandle]
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

section '.data' readable writable

welcomeStr du 'ZippiEFI', 0, 0xFF, 'Copyright (C) 2025 David Badiei', 0, 0xFF, 'Please select an option from below', 0
errorLoadingStr du 'Error loading CONFIG.JSON!', 0xd, 0xa, 0
rebootStr du 'Press any key to reboot...', 0
configFN du 'config.json',0
grubStr du 'GRUB',0
bootmgrStr du 'Windows NT (BOOTMGR)',0
undefinedStr du 'Undefined',0
onDriveStr du ' on drive ',0
currentDriveNum dq 0
currentEFIFileName: times 256 db 0
currentType db 0
countdownNum dq 0
efiSystemTable dq 0
efiLoadedImage dq 0
efiImageHandle dq 0
efiDevicePathHandle dq 0
efiVolumeHandle dq 0
efiRootFSHandle dq 0
efiFileHandle dq 0
efiFileBufferHandle dq 0
efiReadSize dq 1216
efiKeyData dq 0
efiFileInfo dq 0
numOfItems db 0
EFI_LOADED_IMAGE_PROTOCOL_GUID db 0xa1, 0x31, 0x1b, 0x5b, 0x62, 0x95, 0xd2, 0x11, 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID db 0x22, 0x5b, 0x4e, 0x96, 0x59, 0x64, 0xd2, 0x11, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_FILE_INFO_ID_GUID db 0x92, 0x6e, 0x57, 0x09, 0x3f, 0x6d, 0xd2, 0x11, 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b
efiFileInfoBufferSize dq 128
efiFileInfoBuffer: times 128 db 0
blockiouuid db EFI_BLOCK_IO_PROTOCOL_UUID
EFI_FILE_MODE_READ = 0x0000000000000001
include 'include/json.inc'
include 'include/displaystring.inc'