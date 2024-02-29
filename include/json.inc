;ZippiEFI
;JSON include
;Copyright (C) 2024 David Badiei

errorParsingStr du 0x0d, 0x0a, 'Error parsing CONFIG.JSON!', 0xd, 0xa, 0
countdownJSON db 'countdown',0
jsonBuffer: times 21 db 0
jsonTagBuffer: times 256 db 0