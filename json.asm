;ZippiEFI
;JSON stuff
;Copyright (C) 2024 David Badiei

;loadEfiOptions
loadEfiOptions:
;Save highlighted option
mov qword [highlightedRow],rax
;Check if we can read json signature
mov rsi,[efiFileBufferHandle]
mov rax,qword [rsi]
mov rbx,0x45495050495A2F2F
cmp rax,rbx
je skipfailedefisignature
sub rsp,8
mov rsi,errorParsingStr
call printString
mov rsi,rebootStr
call printString
add rsp,8
call waitForAnyKey
call resetPC
skipfailedefisignature:
;Find starting of the json
mov rbx,4
loopFindStartJson:
lodsb
cmp al,'{'
jne loopFindStartJson
;Read and interpret json
loopReadJson:
cmp word [rsi],0x007d
je doneInterpretJson
lodsb
cmp al,'}'
je doneInterpretJsonSection
cmp al,'"'
jne skipReadID
push rdi
call copyToJSONBuffer
push rsi
;Compare the tags
;Check if its countdown
mov rsi,jsonBuffer
mov rdi,countdownJSON
call strcmp
test al,al
jnz skipcountdownconfig
call findAndReadTagsValue
mov rsi,jsonTagBuffer
call atoi
mov qword [countdownNum],rax
jmp skipInitBootOption
skipcountdownconfig:
;Read and initialize the boot
call initBootOption
;Display current boot option while highlighting first option
mov rdx,0
cmp rbx,qword [highlightedRow]
jne skiphighlight
inc rdx
skiphighlight:
call displayBootOption
skipInitBootOption:
pop rsi
inc rsi
pop rdi
skipReadID:
jmp loopReadJson
doneInterpretJsonSection:
inc rbx
jmp loopReadJson
doneInterpretJson:
dec rbx
mov byte [numOfItems],bl
ret
val db 0
highlightedRow dq 0

;copyToJSONBuffer
;IN: RSI = starting position to read
copyToJSONBuffer:
;Clean Buffer
push ax
push rcx
mov rdi,jsonBuffer
mov rcx,21
mov al,0
repe stosb
pop rcx
pop ax
;Copy tag to buffer for comparison
mov rdi,jsonBuffer
loopCopyTag:
movsb
cmp byte [rsi],'"'
jne loopCopyTag
ret

;initBootOption
;Takes value two qwords behind in the stack
initBootOption:
push rax
;Find starting position of tag value
mov rsi,qword [rsp+16]
loopFindTagValueBootOption:
lodsb
cmp al,'{'
je loopFindTagValueBootOption
add rsi,2
;Start reading boot option values
loopBootOptionValues:
lodsb
cmp al,'}'
je doneinitBootOption
cmp al,'"'
jne loopBootOptionValues
call copyToJSONBuffer
push rsi
;Compare the tags
;Check if its drive
mov rsi,jsonBuffer
mov rdi,driveJSON
call strcmp
test al,al
jnz skipdriveconfig
call findAndReadTagsValue
mov rsi,jsonTagBuffer
call atoi
mov qword [currentDriveNum],rax
skipdriveconfig:
;Check if its the efi file name
mov rsi,jsonBuffer
mov rdi,fnJSON
call strcmp
test al,al
jnz skipfnconfig
call findAndReadTagsValue
mov rcx,256
mov rsi,jsonTagBuffer
mov rdi,currentEFIFileName
repe movsb
skipfnconfig:
mov rsi,jsonBuffer
mov rdi,typeJSON
call strcmp
test al,al
jnz skiptypeconfig
call findAndReadTagsValue
mov rsi,jsonTagBuffer
call atoi
and rax,0xff
mov byte [currentType],al
skiptypeconfig:
pop rsi
inc rsi
mov rcx,256
mov rdi,jsonTagBuffer
mov rax,0
repe stosb
jmp loopBootOptionValues
doneinitBootOption:
pop rax
ret

;loadEfiOptions
;Takes value two qwords behind in the stack
findAndReadTagsValue:
push rax
;Find starting position of tag value
mov rsi,qword [rsp+16]
loopFindTagValue:
lodsb
cmp al,' '
je loopFindTagValue
cmp al,':'
je loopFindTagValue
cmp al,'"'
je loopFindTagValue
dec rsi
;Read tag value
mov rdi,jsonTagBuffer
loopReadTagValues:
cmp byte [rsi],','
je doneLoopReadTagValues
cmp byte [rsi],'"'
je doneLoopReadTagValues
cmp byte [rsi],0x0d
je doneLoopReadTagValues
movsb
jmp loopReadTagValues
doneLoopReadTagValues:
pop rax
ret