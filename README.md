# ZippiEFI

ZippiEFI is a EFI bootloader that can chain load other EFI applications.\
It is designed based on the principles of minimalism and efficiency.

# Projected Features
- Clean menu interface to select EFI app/OS
- Optional countdown
- Configuration in JSON file

# Requirements
- Windows or Linux PC. Initially only Windows' boot manager (BOOTMGR) and GRUB will be tested, although others should work as well.
- Secure Boot must be disabled for ZippiEFI to work
- For building ZippiEFI, simply run the makefile (FASM is required).

# DISCLAIMER
This software if not setup properly may cause your system to be unbootable. Use at your own risk.
