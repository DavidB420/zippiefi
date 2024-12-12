;ZippiEFI
;Display and string
;Copyright (C) 2024 David Badiei

;atoi
;IN: RSI = String (ASCII)
;OUT: RAX = signed integer value
atoi:
;Check if number is negative
push rbx
push rsi
push rdx
mov bl,0
cmp byte [rsi],'-'
jne skipusenegative
inc bl
inc rsi
skipusenegative:
;Read and convert number
mov rdx,0
mov rax,0
readConvNum:
lodsb
test al,al
jz doneNumConversion
imul rdx,10
sub al,30h
;Add or sub depending on if num should be negative
test bl,bl
jz skipnegativeconversion
sub rdx,rax
jmp skipositiveconversion
skipnegativeconversion:
add rdx,rax
skipositiveconversion:
jmp readConvNum
doneNumConversion:
xchg rdx,rax
pop rdx
pop rsi
pop rbx
ret

;itoa
;IN: RAX = signed integer value, RCX = str length, RDI = pointer to string (UTF-8)
itoa:
push rax
push rsi
push rdx
push rcx
push rbx
push r8
mov rbx,10
mov r8,rcx
loopgetdigit:
mov rdx,0
idiv rbx
add rdx,30h
push rdx
cmp rax,0
je donegetDigits
loop loopgetdigit
donegetDigits:
test rcx,rcx
jnz skipStopAtArbitrary
mov rcx,r8
jmp skipDontStopAtArbitrary
skipStopAtArbitrary:
mov rbx,rcx
mov rcx,r8
sub rcx,rbx
skipDontStopAtArbitrary:
pop rax
stosw
dec rcx
cmp rcx,0
jg skipDontStopAtArbitrary
pop r8
pop rbx
pop rcx
pop rdx
pop rsi
pop rax
ret

;strcmp
;IN: RSI = First string (ASCII), RDI = Second string (ASCII)
;OUT: AL = 0 (match) 1 (not a match)
strcmp:
push rbx
mov al,0
loopReadByteCmp:
mov bl,byte [rsi]
cmp bl,byte [rdi]
je skipNotMatch
mov al,1
skipNotMatch:
inc rsi
inc rdi
cmp bl,0
jne loopReadByteCmp
pop rbx
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
sub rsp,32
call printString
add rsp,32
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
push rdx
cmp dl,1
jne skipsethighlight
mov rdx,0x70
call setConsoleHighlight
skipsethighlight:
;Get ConOut in rcx, then use that to get the pointer for the OutputString function in rax 
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.OutputString]
xchg rdx,rsi
;Setup shadow space for GPRs
sub rsp,32
call rax
add rsp,32
pop rdx
cmp dl,1
jne skipremovehighlight
mov rdx,0x07
call setConsoleHighlight
skipremovehighlight:
pop rsi
pop rax
pop rcx
pop rdx
ret

;setConsoleHighlight
;IN: RDX = Color code
setConsoleHighlight:
push rdx
mov rdx,qword [efiSystemTable]
mov rcx,[rdx+EFI_SYSTEM_TABLE.ConOut]
mov rax,[rcx+SIMPLE_TEXT_OUTPUT_INTERFACE.SetAttribute]
pop rdx
sub rsp,32
call rax
add rsp,32
ret

;numToString (UTF-16)
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

displayBootOption:
push rax
push rsi
push rbx
push rcx
push rdi
mov al,byte [currentType]
cmp al,0
jne skipgruboutput
mov rsi,grubStr
mov rcx,4
skipgruboutput:
cmp al,1
jne skipbootmgroutput
mov rsi,bootmgrStr
mov rcx,20
skipbootmgroutput:
cmp al,2
jne skipundefinedoutput
mov rsi,undefinedStr
mov rcx,9
skipundefinedoutput:
mov rdi,displayBootOptionsStr
repe movsw
mov rsi,onDriveStr
mov rcx,10
repe movsw
push rdi
mov rax,[currentDriveNum]
mov rdi,numberBuffer
mov rcx,4
call itoa
pop rdi
mov rsi,numberBuffer
repe movsw
mov rsi,displayBootOptionsStr
call centeredPrintString
pop rdi
pop rcx
pop rbx
pop rsi
pop rax
ret