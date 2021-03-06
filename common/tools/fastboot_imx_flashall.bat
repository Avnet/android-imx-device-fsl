:: This script is used for flashing i.MX android images whit fastboot.

@echo off

::---------------------------------------------------------------------------------
::Variables
::---------------------------------------------------------------------------------

:: For batch script, %0 is not script name in a so-called function, so save the script name here
set script_first_argument=%0
:: For users execute this script in powershell, clear the quation marks first.
set script_first_argument=%script_first_argument:"=%
:: reserve last 25 characters, which is the lenght of the name of this script file.
set script_name=%script_first_argument:~-25%

set soc_name=
set device_character=
set /A card_size=0
set slot=
set bootimage=boot.img
set systemimage_file=system.img
set vendor_file=vendor.img
set partition_file=partition-table.img
set /A support_dtbo=0
set /A support_recovery=0
set /A support_dualslot=0
set /A support_m4_os=0
set bootloader_partition=bootloader
set boot_partition=boot
set recovery_partition=recovery
set system_partition=system
set vendor_partition=vendor
set vbmeta_partition=vbmeta
set dtbo_partition=dtbo
set m4_os_partition=m4_os
set /A flash_m4=0
set /A statisc=0
set /A lock=0
set /A erase=0
set image_directory=
set ser_num=
set fastboot_tool=fastboot


::---------------------------------------------------------------------------------
::Parse command line
::---------------------------------------------------------------------------------
:: If no option provied when executing this script, show help message and exit.
if [%1] == [] call :help goto :eof

:parse_loop
if [%1] == [] goto :parse_end
if %1 == -h call :help & goto :eof
if %1 == -f set soc_name=%2& shift & shift & goto :parse_loop
if %1 == -c set /A card_size=%2& shift & shift & goto :parse_loop
if %1 == -d set device_character=%2& shift & shift & goto :parse_loop
if %1 == -a set slot=_a& shift & goto :parse_loop
if %1 == -b set slot=_b& shift & goto :parse_loop
if %1 == -m set /A flash_m4=1 & shift & goto :parse_loop
if %1 == -l set /A lock=1 & shift & goto :parse_loop
if %1 == -e set /A erase=1 & shift & goto :parse_loop
if %1 == -D set image_directory=%2& shift & shift & goto :parse_loop
if %1 == -s set ser_num=%2&shift &shift & goto :parse_loop
call :help & goto :eof
:parse_end

:: If sdcard size is not correctly set, exit
if %card_size% neq 0 set /A statisc+=1
if %card_size% neq 7 set /A statisc+=1
if %card_size% neq 14 set /A statisc+=1
if %card_size% neq 28 set /A statisc+=1
if %statisc% == 4 echo card_size is not a legal value & goto :eof

if %card_size% gtr 0 set partition_file=partition-table-%card_size%GB.img

:: if directory is specified, and the last character is not backslash, add one backslash
if not [%image_directory%] == [] if not %image_directory:~-1% == \ (
    set image_directory=%image_directory%\
)

if not [%ser_num%] == [] set fastboot_tool=fastboot -s %ser_num%

::---------------------------------------------------------------------------------
:: Invoke function to flash android images
::---------------------------------------------------------------------------------
call :flash_android

if %erase% == 1 (
    %fastboot_tool% erase userdata
    %fastboot_tool% erase misc
    if %soc_name:imx8=% == %soc_name% (
        %fastboot_tool% erase cache
    )
)
if %lock% == 1 %fastboot_tool% oem lock

echo #######ALL IMAGE FILES FLASHED#######


::---------------------------------------------------------------------------------
:: The execution will end.
::---------------------------------------------------------------------------------
goto :eof


::----------------------------------------------------------------------------------
:: Function definition
::----------------------------------------------------------------------------------

:help
echo Version: 1.2
echo Last change: Add -s option. fix errors when -D option not specified. handle situations that illegal options provided.
echo.
echo eg: fastboot_imx_flashall.bat -f imx8mm -a -D C:\Users\user_01\Android\images\2018.10.07\evk_8mm
echo eg: fastboot_imx_flashall.bat -f imx7ulp -D C:\Users\user_01\Android\images\2018.10.07\evk_7ulp
echo.
echo Usage: %script_name% ^<option^>
echo.
echo options:
echo  -h                displays this help message
echo  -f soc_name       flash android image file with soc_name
echo  -a                only flash image to slot_a
echo  -b                only flash image to slot_b
echo  -c card_size      optional setting: 7 / 14 / 28
echo                        If not set, use partition-table.img (default)
echo                        If set to  7, use partition-table-7GB.img  for  8GB SD card
echo                        If set to 14, use partition-table-14GB.img for 16GB SD card
echo                        If set to 28, use partition-table-28GB.img for 32GB SD card
echo                    Make sure the corresponding file exist for your platform
echo  -m                flash m4 image
echo  -d dev            flash dtbo, vbmeta and recovery image file with dev
echo                        If not set, use default dtbo, vbmeta and recovery image
echo  -e                erase user data after all image files being flashed
echo  -l                lock the device after all image files being flashed
echo  -D directory      the directory of of images
echo                        No need to use this option if images and this script are in same directory
echo  -s ser_num        the serial number of board
echo                        If only one board connected to computer, no need to use this option
goto :eof


:flash_partition
:: if there is slot information, delete it.
set local_str=%1
set local_str=%local_str:_a=%
set local_str=%local_str:_b=%

set img_name=%local_str%-%soc_name%.img

if not [%local_str:system=%] == [%local_str%] set img_name=%systemimage_file%
if not [%local_str:vendor=%] == [%local_str%] set img_name=%vendor_file%
if %support_dtbo% == 1 if not [%local_str:boot=%] == [%local_str%] set img_name=%bootimage%
if not [%local_str:m4_os=%] == [%local_str%] set img_name=%soc_name%_m4_demo.img
if not [%local_str:vbmeta=%] == [%local_str%] if not [%device_character%] == [] (
    set img_name=%local_str%-%soc_name%-%device_character%.img
)
if not [%local_str:dtbo=%] == [%local_str%] if not [%device_character%] == [] (
    set img_name=%local_str%-%soc_name%-%device_character%.img
)
if not [%local_str:recovery=%] == [%local_str%] if not [%device_character%] == [] (
    set img_name=%local_str%-%soc_name%-%device_character%.img
)
if not [%local_str:bootloader=%] == [%local_str%] set img_name=u-boot-%soc_name%.imx
if not [%local_str:gpt=%] == [%local_str%] set img_name=%partition_file%


%fastboot_tool% flash %1 %image_directory%%img_name%
goto :eof


:flash_userpartitions
if %support_dtbo% == 1 call :flash_partition %dtbo_partition%
if %support_recovery% == 1 call :flash_partition %recovery_partition%
call :flash_partition %boot_partition%
call :flash_partition %system_partition%
call :flash_partition %vendor_partition%
call :flash_partition %vbmeta_partition%
goto :eof


:flash_partition_name
set boot_partition=boot%1
set recovery_partition=recovery%1
set system_partition=system%1
set vendor_partition=vendor%1
set vbmeta_partition=vbmeta%1
set dtbo_partition=dtbo%1
goto :eof

:flash_android
if not %soc_name:imx8=% == %soc_name% set bootloader_partition=bootloader0
call :flash_partition %bootloader_partition%

call :flash_partition gpt

%fastboot_tool% getvar all 2> fastboot_var.log && find "dtbo" fastboot_var.log > nul && set /A support_dtbo=1

find "recovery" fastboot_var.log > nul && set /A support_recovery=1

::use boot_b to check whether current gpt support a/b slot
find "boot_b" fastboot_var.log > nul && set /A support_dualslot=1

find "m4_os" fastboot_var.log > nul && set /A support_m4_os=1


if %support_dualslot% == 0 set slot=


if %flash_m4% == 1 if %support_m4_os% == 1 call :flash_partition %m4_os_partition%


if [%slot%] == [] if %support_dualslot% == 1 (
:: flash image to both a and b slot
    call :flash_partition_name _a
    call :flash_userpartitions

    call :flash_partition_name _b
    call :flash_userpartitions
)
if not [%slot%] == []  if %support_dualslot% == 1 (
    call :flash_partition_name %slot%
    call :flash_userpartitions
    %fastboot_tool% set_active %slot:~-1%
)

if %support_dualslot% == 0 (
    call :flash_partition_name %slot%
    call :flash_userpartitions
)

del fastboot_var.log

goto :eof
