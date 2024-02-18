format pe64 efi
entry main

section '.text' executable readable

include 'uefi.inc'

main:
;Save EFI system table that is loaded into rdx
mov qword [efiSystemTable],rdx
mov qword [efiImageHandle],rcx
;Output welcome message
mov rsi,welcomeStr
call printString
;Begin to load the file system
call initEfiFileSystem
mov r8,ldrFN
call openFile
;Setup GOP
call setupGOP
;Exit boot services
mov rax,qword [efiSystemTable]
mov rax,[rax+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [rax+EFI_BOOT_SERVICES_TABLE.ExitBootServices]
add rsp,32
;Move file to proper memory address
mov rsi,[efiOSBufferHandle]
mov rdi,0x20000
mov rcx,[efiReadSize]
repe movsb
call elfLoad
;Jump to kernel
mov esi,[frameBufferPPS]
mov rdi,[uefiGOPHandle]
jmp 0x30000
ret

elfLoad:
;Check ELF signature
cmp dword [20001h],1179403647
je failElfLoad
;Get Program entry and program header pos
mov rax,qword [20018h]
mov rbx,qword [20020h]
mov r8w,word [20038h]
;Read and load program entries
add rbx,20008h
loopreadProgEntries:
mov rcx,qword [rbx]
mov rdx,qword [rbx+8]
test rcx,rcx
jz skipCopyDataElf
mov r9,qword [rbx+24]
mov rsi,rcx
add rsi,20000h
mov rdi,rdx
mov rcx,r9
repe movsb
skipCopyDataElf:
add rbx,56
dec r8
cmp r8,0
jne loopreadProgEntries
failElfLoad:
ret

setupGOP:
;Get GOP pointer
lea rcx,[gopguid]
mov rdx,0
lea r8,[efiGOPHandle]
mov r9,qword [efiSystemTable]
mov r9,[r9+EFI_SYSTEM_TABLE.BootServices]
sub rsp,32
call qword [r9+EFI_BOOT_SERVICES_TABLE.LocateProtocol]
add rsp,32
;Get current video mode
mov rcx,[efiGOPHandle]
mov edx,dword [rcx+EFI_GRAPHICS_OUTPUT_PROTOCOL.Mode]
mov edx,dword [rdx+EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE.CurrentMode]
and edx,edx
lea r8,[gopModeSize]
lea r9,[gopModeInfo]
sub rsp,32
call qword [rcx+EFI_GRAPHICS_OUTPUT_PROTOCOL.QueryMode]
add rsp,32
mov r9, qword [gopModeInfo]
mov eax,dword [r9+EFI_GRAPHICS_OUTPUT_MODE_INFORMATION.VerticalResolution]
mov ebx,dword [r9+EFI_GRAPHICS_OUTPUT_MODE_INFORMATION.HorizontalResolution]
;Query number of video modes
mov rax,[efiGOPHandle]
mov rax,[rax+EFI_GRAPHICS_OUTPUT_PROTOCOL.Mode]
mov ecx,dword [rax+EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE.MaxMode]
and ecx,ecx
dec rcx
loopgetgopmodes:
push rcx
mov rdx,rcx
mov rcx,[efiGOPHandle]
lea r8,[gopModeSize]
lea r9,[gopModeInfo]
sub rsp,32
call qword [rcx+EFI_GRAPHICS_OUTPUT_PROTOCOL.QueryMode]
add rsp,32
mov r9, qword [gopModeInfo]
mov eax,dword [r9+EFI_GRAPHICS_OUTPUT_MODE_INFORMATION.VerticalResolution]
mov ebx,dword [r9+EFI_GRAPHICS_OUTPUT_MODE_INFORMATION.HorizontalResolution]
imul rax,rbx
cmp rax,qword [currentHighestRes]
jl skipsethighestres
mov byte [currentHighestIndex],dl
mov qword [currentHighestRes],rax
mov eax,dword [r9+EFI_GRAPHICS_OUTPUT_MODE_INFORMATION.PixelsPerScanline]
mov dword [frameBufferPPS],eax
skipsethighestres:
pop rcx
loop loopgetgopmodes
;Set the highest resolution as the video mode
mov dl,byte [currentHighestIndex]
mov rcx,[efiGOPHandle]
sub rsp,32
call qword [rcx+EFI_GRAPHICS_OUTPUT_PROTOCOL.SetMode]
add rsp,32
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

waitForAnyKey:
mov rdx,1
mov rcx,[efiSystemTable]
mov rcx,[rcx+EFI_SYSTEM_TABLE.ConIn]
sub rsp,32
call qword [rcx+EFI_SIMPLE_TEXT_INPUT_PROTOCOL.Reset]
add rsp,32
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

welcomeStr du 'Doors++ UEFI bootloader', 0xD, 0xA, 0
errorStr du 'Error loading PPKRNL.SYS!', 0xd, 0xa, 'Press any key to reboot...',0
ldrFN du 'ppkrnl.sys',0
efiSystemTable dq 0
efiLoadedImage dq 0
efiImageHandle dq 0
efiDevicePathHandle dq 0
efiVolumeHandle dq 0
efiRootFSHandle dq 0
efiFileHandle dq 0
efiOSBufferHandle dq 0
efiGOPHandle dq 0
efiReadSize dq 1216
efiKeyData dq 0
efiFileInfo dq 0
currentHighestRes dq 0
currentHighestIndex db 0
frameBufferPPS dd 0
uefiGOPHandle dq 0
EFI_LOADED_IMAGE_PROTOCOL_GUID db 0xa1, 0x31, 0x1b, 0x5b, 0x62, 0x95, 0xd2, 0x11, 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID db 0x22, 0x5b, 0x4e, 0x96, 0x59, 0x64, 0xd2, 0x11, 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
EFI_FILE_INFO_ID_GUID db 0x92, 0x6e, 0x57, 0x09, 0x3f, 0x6d, 0xd2, 0x11, 0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b
efiFileInfoBufferSize dq 128
efiFileInfoBuffer: times 128 db 0
blockiouuid db EFI_BLOCK_IO_PROTOCOL_UUID
gopguid db EFI_GRAPHICS_OUTPUT_PROTOCOL_UUID
gopMax dd 0
gopModeSize dq 0
gopModeInfo dd 0,0,0,0,0,0,0,0
EFI_FILE_MODE_READ = 0x0000000000000001
secondStageLoc = 0x030000