;ZippiEFI
;Display and string
;Copyright (C) 2024 David Badiei

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
push rbx
;Run through each line, must use 0x0000, 0x00ff as newline seperator
loopPrintCenteredString:
;Calculate and set starting point so string is at the center
mov rax,[textColumns]
shr rax,1
call getUnicodeStringLength
push rcx
shr rcx,1
sub rax,rcx
call setCursorPos
;Display string using the regular function
sub rsp,8
call printString
add rsp,8
pop rcx
shl rcx,1
add rsi,rcx
add rsi,4
inc rbx
cmp word [rsi-2],0x00ff
je loopPrintCenteredString
pop rbx
pop rcx
pop rax
ret

;getUnicodeStringLength
;IN: RSI = string pointer
;OUT: RCX = length of string
getUnicodeStringLength:
push rax
push rsi
;Character is word lengthed, keep counting until end of string or newline
mov rcx,0
loopReadStringValues:
lodsw
test ax,ax
jz gotStringLength
cmp ax,0x0d
je gotStringLength
cmp ax,0xff
je gotStringLength
inc rcx
jmp loopReadStringValues
gotStringLength:
pop rsi
pop rax
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
