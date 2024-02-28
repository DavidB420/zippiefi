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
;Copy tag to buffer for comparison
mov rdi,jsonBuffer
loopCopyTag:
movsb
cmp byte [rsi],'"'
jne loopCopyTag
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
cli
jmp $
skipcountdownconfig:
pop rsi
pop rdi
skipReadID:
jmp loopReadJson
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