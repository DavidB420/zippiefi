OUTPUT = zippiefi.efi

SOURCE = zippiefi.asm

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	fasm $< $@

clean:
	rm -f $(OUTPUT)
