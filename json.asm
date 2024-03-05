;ZippiEFI
;JSON stuff
;Copyright (C) 2024 David Badiei

;loadEfiOptions
loadEfiOptions:
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
loopFindStartJson:
lodsb
cmp al,'{'
jne loopFindStartJson
;Read and interpret json
loopReadJson:
lodsb
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
skipInitBootOption:
pop rsi
inc rsi
pop rdi
skipReadID:
jmp loopReadJson
ret

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
cli
jmp $
skipdriveconfig:
pop rsi
pop rax
cli
jmp $
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