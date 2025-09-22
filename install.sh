#!/bin/bash
#==============================================================================
# DigiRDP Windows Installer v1.0
# Copyright (c) 2025 DigiRDP Solutions - All Rights Reserved
#==============================================================================

set -e

# Set parameters
export DIGIRDP_VALIDATED="true"
export SERVER_IP="176.9.48.136"
export SERVER_GATEWAY=""
export WINDOWS_VERSION="2022"
export ADMIN_PASSWORD="Noxhost@89$"

# Include core installer functions
# !/bin/bash
#==============================================================================
# DigiRDP Core Windows Installer
# Copyright (c) 2025 DigiRDP, LLC
#==============================================================================

# Function to check if running in screen
check_and_launch_screen() {
    if [ -z "${STY:-}" ]; then
        # Not in screen
        echo "Starting installation in a new screen session..."
        echo

        # Install screen if not available
        if ! command -v screen >/dev/null 2>&1; then
            echo "Installing screen..."
            apt-get update >/dev/null 2>&1
            apt-get install -y screen >/dev/null 2>&1
        fi

        # Create a unique screen session name
        SESSION_NAME="digirdp_install_$$"

        echo "Launching installer in screen session: $SESSION_NAME"
        echo
        echo "To detach from the installation: Press Ctrl+A then D"
        echo "To reattach later: screen -r $SESSION_NAME"
        echo
        echo "Press any key to continue..."
        read -n 1

        # Start script in screen with all arguments
        screen -S "$SESSION_NAME" "$0" "$@"

        # Script will exit here in the original shell
        exit 0
    fi
}

# Main installation function
perform_installation() {
    local SERVER_IP="${1:-auto}"
    local SERVER_GATEWAY="${2:-auto}"
    local WINDOWS_VERSION="${3:-2022}"
    local ADMIN_PASSWORD="${4:-}"
    local DEFAULT_PASSWORD="DigiRDP2025!"

    # Set password
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD="$DEFAULT_PASSWORD"
        USING_DEFAULT_PASSWORD=true
    else
        USING_DEFAULT_PASSWORD=false
    fi

    # Colors and Styles
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BRIGHT_CYAN='\033[1;36m'
    BRIGHT_GREEN='\033[1;32m'
    BRIGHT_YELLOW='\033[1;33m'
    BRIGHT_BLUE='\033[1;34m'
    NC='\033[0m'

    # Function to clear screen and show banner
    show_banner() {
        clear
        echo
        echo -e "${BRIGHT_CYAN}=================================================================================${NC}"
        echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}DDDDD  IIIII  GGGGG  IIIII RRRRR  DDDDD  PPPPPP${NC}    ${BRIGHT_YELLOW}[TM]${NC}                ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}D   D    I   G     G   I   R   R  D   D  P     P${NC}                        ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}D    D   I   G         I   R    R D    D P     P${NC}                        ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}D    D   I   G   GGG   I   RRRRR  D    D PPPPPP${NC}                         ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}D    D   I   G     G   I   R  R   D    D P${NC}                              ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}D   D    I   G     G   I   R   R  D   D  P${NC}                              ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}     ${BRIGHT_BLUE}DDDDD  IIIII  GGGGG  IIIII R    R DDDDD  P${NC}                              ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
        echo -e "${BRIGHT_CYAN}|-------------------------------------------------------------------------------|${NC}"
        echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}               ${BRIGHT_GREEN}>>> ${BRIGHT_YELLOW}Windows Server Automated Installation${NC} ${BRIGHT_GREEN}<<<${NC}                ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}                                                                               ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}                      ${DIM}Enterprise Edition v1.0.0${NC}                               ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}                     ${DIM}Copyright (C) 2025 DigiRDP, LLC${NC}                          ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|${NC}                        ${DIM}All Rights Reserved${NC}                                   ${BRIGHT_CYAN}|${NC}"
        echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
        echo -e "${BRIGHT_CYAN}=================================================================================${NC}"
        echo
    }

    # Progress bar function
    progress_bar() {
        local duration=$1
        local message=$2
        local width=50
        local progress=0

        echo -ne "\n  ${CYAN}${message}${NC}\n  ["

        while [ $progress -le $width ]; do
            echo -ne "\r  ["
            for ((i=0; i<$progress; i++)); do
                echo -ne "${GREEN}#${NC}"
            done
            for ((i=$progress; i<$width; i++)); do
                echo -ne " "
            done
            echo -ne "] $(( progress * 2 ))%"
            progress=$((progress + 1))
            sleep $(echo "scale=2; $duration / $width" | bc 2>/dev/null || echo "0.04")
        done
        echo -ne "\r  [${GREEN}$(printf '#%.0s' {1..50})${NC}] 100% ${GREEN}[OK]${NC}\n"
    }

    # Spinner function
    spinner() {
        local pid=$1
        local message=$2
        local spin='|/-\'
        local i=0

        echo -ne "\n  ${CYAN}${message}${NC} "
        while kill -0 $pid 2>/dev/null; do
            i=$(( (i+1) %4 ))
            echo -ne "\r  ${CYAN}${message}${NC} ${YELLOW}${spin:$i:1}${NC} "
            sleep .1
        done
        echo -ne "\r  ${CYAN}${message}${NC} ${GREEN}[OK]${NC}\n"
    }

    # Print functions
    print_step() {
        echo -e "\n${BRIGHT_BLUE}==>${NC} ${BOLD}$1${NC}"
    }

    print_info() {
        echo -e "  ${BLUE}[INFO]${NC} $1"
    }

    print_success() {
        echo -e "  ${GREEN}[OK]${NC} $1"
    }

    print_error() {
        echo -e "  ${RED}[FAIL]${NC} $1"
    }

    print_warning() {
        echo -e "  ${YELLOW}[WARN]${NC} $1"
    }

    # cleanup function
    cleanup() {
        if [ -d "/mnt/wininstall" ]; then
            cd /
            umount /mnt/wininstall 2>/dev/null || true
        fi
    }
    trap cleanup EXIT INT TERM

    # Show banner
    show_banner

    # System preparation
    print_step "System Preparation"
    progress_bar 2 "Initializing installation environment"

    # Kill any existing qemu
    pkill -f qemu 2>/dev/null && sleep 2
    umount -f /mnt/wininstall 2>/dev/null || true

    # Check disks and hardware
    print_step "Hardware Detection"
    
    # Detect UEFI vs BIOS
    if [ -d /sys/firmware/efi ]; then
        print_success "UEFI system detected - will use GPT partitioning"
        BOOT_MODE="UEFI"
    else
        print_warning "BIOS system detected - will use legacy partitioning"
        BOOT_MODE="BIOS"
    fi
    
    DISKS=($(lsblk -dn -o NAME,TYPE | grep disk | awk '{print $1}'))

    if [ ${#DISKS[@]} -lt 2 ]; then
        if [ ${#DISKS[@]} -eq 1 ]; then
            TARGET_DISK="/dev/${DISKS[0]}"
            WORK_DIR="/tmp/wininstall"
            mkdir -p "$WORK_DIR"
        else
            print_error "No disks found!"
            exit 1
        fi
    else
        TARGET_DISK="/dev/${DISKS[0]}"
        WORK_DISK="/dev/${DISKS[1]}"
        print_success "Detected ${#DISKS[@]} drives"
    fi

    # Network config
    print_step "Network Configuration"

    if [ "$SERVER_IP" = "auto" ]; then
        echo -ne "  ${CYAN}Auto-detecting IP address${NC} "
        for i in {1..3}; do
            echo -ne "."
            sleep 0.5
        done
        SERVER_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d/ -f1)
        echo -e " ${GREEN}[OK]${NC}"
    fi

    if [ "$SERVER_GATEWAY" = "auto" ]; then
        echo -ne "  ${CYAN}Auto-detecting gateway${NC} "
        for i in {1..3}; do
            echo -ne "."
            sleep 0.5
        done
        SERVER_GATEWAY=$(ip route | grep default | awk '{print $3}')
        echo -e " ${GREEN}[OK]${NC}"
    fi

    if [ -z "$SERVER_IP" ] || [ -z "$SERVER_GATEWAY" ]; then
        print_error "Network detection failed"
        exit 1
    fi

    # Generate random computer name
    RANDOM_SUFFIX=$(head /dev/urandom | tr -dc 'A-Z0-9' | head -c 4)
    COMPUTER_NAME="WIN-${RANDOM_SUFFIX}"

    # Configuration display will be shown later after boot mode detection

    # find qemu
    print_step "Checking System Requirements"
    QEMU_BIN=""
    for q in qemu-system-x86_64 kvm qemu-kvm; do
        if command -v $q >/dev/null 2>&1; then
            QEMU_BIN=$q
            break
        fi
    done

    if [ -z "$QEMU_BIN" ]; then
        print_warning "QEMU not found - installing..."
        apt-get update >/dev/null 2>&1 &
        spinner $! "Updating package database"
        apt-get install -y qemu-kvm >/dev/null 2>&1 &
        spinner $! "Installing QEMU/KVM"
        QEMU_BIN="qemu-system-x86_64"
    else
        print_success "QEMU/KVM detected"
    fi

    # Install other deps if needed (including OVMF for UEFI support)
    for pkg in genisoimage bc dosfstools lsof ntfs-3g ovmf; do
        if ! command -v $pkg >/dev/null 2>&1 && ! dpkg -l | grep -q "^ii.*$pkg "; then
            apt-get install -y $pkg >/dev/null 2>&1 || true
        fi
    done

    # Prep work disk
    if [ -n "${WORK_DISK:-}" ]; then
        print_step "Preparing Work Environment"

        wipefs -a -f "$WORK_DISK" 2>/dev/null || true
        dd if=/dev/zero of="$WORK_DISK" bs=1M count=100 2>/dev/null || true &
        spinner $! "Wiping work disk"

        parted -s "$WORK_DISK" mklabel gpt >/dev/null 2>&1
        parted -s "$WORK_DISK" mkpart primary ext4 1MiB 100% >/dev/null 2>&1
        parted -s "$WORK_DISK" set 1 legacy_boot on >/dev/null 2>&1
        sleep 2

        # Find partition
        if [ -e "${WORK_DISK}1" ]; then
            WORK_PART="${WORK_DISK}1"
        elif [ -e "${WORK_DISK}p1" ]; then
            WORK_PART="${WORK_DISK}p1"
        else
            print_error "Work partition not found"
            exit 1
        fi

        mkfs.ext4 -F "$WORK_PART" >/dev/null 2>&1 &
        spinner $! "Creating filesystem"

        mkdir -p /mnt/wininstall
        mount "$WORK_PART" /mnt/wininstall
        WORK_DIR="/mnt/wininstall"

        AVAILABLE=$(df -h $WORK_DIR | awk 'NR==2 {print $4}')
        print_success "Work disk ready - ${AVAILABLE} available"
    fi

    # Download ISO
    ISO="$WORK_DIR/windows.iso"
    case "$WINDOWS_VERSION" in
        "2022") ISO_URL="https://mirror.hetzner.de/bootimages/windows/SW_DVD9_Win_Server_STD_CORE_2022_2108.15_64Bit_English_DC_STD_MLF_X23-31801.ISO" ;;
        "2019") ISO_URL="https://mirror.hetzner.de/bootimages/windows/SW_DVD9_Win_Server_STD_CORE_2019_1809.11_64Bit_English_DC_STD_MLF_X22-51041.ISO" ;;
        "2016") ISO_URL="https://mirror.hetzner.de/bootimages/windows/SW_DVD9_Win_Svr_STD_Core_and_DataCtr_Core_2016_64Bit_English_-3_MLF_X21-30350.ISO" ;;
        *) ISO_URL="https://mirror.hetzner.de/bootimages/windows/SW_DVD9_Win_Server_STD_CORE_2022_2108.15_64Bit_English_DC_STD_MLF_X23-31801.ISO" ;;
    esac

    if [ ! -f "$ISO" ]; then
        print_step "Downloading Windows Server $WINDOWS_VERSION"
        echo -e "  ${DIM}This may take 5-10 minutes depending on your connection...${NC}\n"

        wget --progress=bar:force:noscroll --tries=3 --timeout=30 -O "$ISO" "$ISO_URL" 2>&1 | \
        grep --line-buffered "%" | \
        sed -u -e "s/.* \([0-9]\+\)%.*/\1/" | \
        while read percent; do
            echo -ne "\r  Downloading: ["
            filled=$((percent / 2))
            for ((i=0; i<filled; i++)); do echo -ne "${GREEN}#${NC}"; done
            for ((i=filled; i<50; i++)); do echo -ne " "; done
            echo -ne "] ${percent}%"
        done
        echo -e "\n"
        print_success "Windows ISO downloaded successfully"
    else
        print_success "Windows ISO already present"
    fi

    # Create autounattend
    print_step "Creating Automated Installation Configuration"
    
    # Generate partition configuration based on VM boot mode (not host boot mode)
    if [ "$USE_UEFI" = "yes" ]; then
        PARTITION_CONFIG='                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Type>EFI</Type>
                            <Order>1</Order>
                            <Size>200</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Type>MSR</Type>
                            <Order>2</Order>
                            <Size>128</Size>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>FAT32</Format>
                            <Label>System</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
        INSTALL_PARTITION="3"
    else
        PARTITION_CONFIG='                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Active>true</Active>
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>'
        INSTALL_PARTITION="1"
    fi
    
    cat > "$WORK_DIR/autounattend.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
                <WillShowUI>Never</WillShowUI>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
$PARTITION_CONFIG
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>2</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>$INSTALL_PARTITION</PartitionID>
                    </InstallTo>
                    <WillShowUI>OnError</WillShowUI>
                </OSImage>
            </ImageInstall>
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>DigiRDP</Organization>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>UTC</TimeZone>
            <ComputerName>$COMPUTER_NAME</ComputerName>
        </component>
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <AutoLogon>
                <Password>
                    <Value>$ADMIN_PASSWORD</Value>
                    <PlainText>true</PlainText>
                </Password>
                <LogonCount>5</LogonCount>
                <Username>Administrator</Username>
                <Enabled>true</Enabled>
            </AutoLogon>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$ADMIN_PASSWORD</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell -Command "New-NetIPAddress -InterfaceAlias Ethernet -IPAddress $SERVER_IP -PrefixLength 32 -DefaultGateway $SERVER_GATEWAY"</CommandLine>
                    <Order>1</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell -Command "Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses 185.12.64.1, 185.12.64.2"</CommandLine>
                    <Order>2</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f</CommandLine>
                    <Order>3</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>netsh advfirewall firewall set rule group="remote desktop" new enable=Yes</CommandLine>
                    <Order>4</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>net accounts /lockoutthreshold:0</CommandLine>
                    <Order>5</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f</CommandLine>
                    <Order>6</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>echo Installation Complete > C:\install_complete.txt</CommandLine>
                    <Order>7</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
EOF

    print_success "Configuration file created"
    
    # Debug: Show which partition configuration was used
    if [ "$USE_UEFI" = "yes" ]; then
        print_info "Using UEFI partition layout (EFI + MSR + Windows)"
    else
        print_info "Using Legacy BIOS partition layout (Boot + Windows)"
    fi

    # Create ISO
    print_step "Building Custom Installation Media"

    mkdir -p "$WORK_DIR/mnt" "$WORK_DIR/iso_extract"

    mount -o loop,ro "$ISO" "$WORK_DIR/mnt" 2>/dev/null || {
        print_error "Failed to mount ISO!"
        exit 1
    }

    cp -r "$WORK_DIR/mnt/"* "$WORK_DIR/iso_extract/" 2>/dev/null &
    spinner $! "Extracting ISO contents"

    umount "$WORK_DIR/mnt"
    rmdir "$WORK_DIR/mnt"

    cp "$WORK_DIR/autounattend.xml" "$WORK_DIR/iso_extract/"
    cp "$WORK_DIR/autounattend.xml" "$WORK_DIR/iso_extract/Autounattend.xml"

    cd "$WORK_DIR/iso_extract"

    # create iso - try different methods
    if [ -f "boot/etfsboot.com" ]; then
        genisoimage -b boot/etfsboot.com -no-emul-boot -c BOOT.CAT \
            -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames \
            -V "WIN$WINDOWS_VERSION" -udf -allow-limited-size \
            -o "$WORK_DIR/windows_custom.iso" . >/dev/null 2>&1 || {
            # fallback to original iso + floppy
            cp "$ISO" "$WORK_DIR/windows_custom.iso"
            dd if=/dev/zero of="$WORK_DIR/autounattend.img" bs=1440K count=1 2>/dev/null
            mkfs.vfat "$WORK_DIR/autounattend.img" >/dev/null 2>&1
            mkdir -p "$WORK_DIR/floppy_mount"
            mount -o loop "$WORK_DIR/autounattend.img" "$WORK_DIR/floppy_mount"
            cp "$WORK_DIR/autounattend.xml" "$WORK_DIR/floppy_mount/"
            umount "$WORK_DIR/floppy_mount"
            rmdir "$WORK_DIR/floppy_mount"
        }
    else
        # just use original
        cp "$ISO" "$WORK_DIR/windows_custom.iso"
    fi

    cd /
    rm -rf "$WORK_DIR/iso_extract"

    print_success "Installation media ready"

    # Prep target
    print_step "Preparing Target Disk"
    dd if=/dev/zero of=$TARGET_DISK bs=1M count=100 2>/dev/null &
    spinner $! "Wiping disk partition table"

    # Start VM
    print_step "Launching Windows Installation"

    # Check CPU virtualization support first
    CPU_SUPPORTS_VT=""
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        if [ -r /dev/kvm ]; then
            CPU_SUPPORTS_VT="yes"
            print_success "CPU virtualization support detected"
        else
            print_warning "CPU supports virtualization but KVM module not loaded"
            CPU_SUPPORTS_VT="limited"
        fi
    else
        print_warning "CPU does not support hardware virtualization (VT-x/AMD-V)"
        CPU_SUPPORTS_VT="no"
    fi

    # Check for UEFI BIOS file and CPU compatibility
    UEFI_BIOS=""
    USE_UEFI="no"
    
    # Check if user wants to force legacy BIOS
    if [ "${FORCE_LEGACY_BIOS:-}" = "1" ] || [ "${DISABLE_UEFI:-}" = "1" ]; then
        print_warning "UEFI disabled by user - forcing legacy BIOS mode"
        USE_UEFI="no"
    # Only try UEFI if CPU supports virtualization properly
    elif [ "$CPU_SUPPORTS_VT" = "yes" ]; then
        for bios_path in /usr/share/ovmf/OVMF.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF.fd; do
            if [ -f "$bios_path" ]; then
                # Test OVMF compatibility with a quick test
                print_info "Testing OVMF compatibility..."
                if timeout 10s qemu-system-x86_64 -bios "$bios_path" -M pc -m 512 -nographic -serial null -monitor null -daemonize -pidfile /tmp/ovmf_test.pid 2>/dev/null; then
                    # Kill the test VM
                    if [ -f /tmp/ovmf_test.pid ]; then
                        kill $(cat /tmp/ovmf_test.pid) 2>/dev/null || true
                        rm -f /tmp/ovmf_test.pid
                    fi
                    UEFI_BIOS="$bios_path"
                    USE_UEFI="yes"
                    print_success "OVMF compatibility test passed"
                    break
                else
                    print_warning "OVMF compatibility test failed for $bios_path"
                fi
            fi
        done
        
        # If all tests failed, disable UEFI
        if [ "$USE_UEFI" = "no" ]; then
            print_warning "All OVMF tests failed - falling back to legacy BIOS"
        fi
    fi

    if [ "$USE_UEFI" = "yes" ]; then
        print_success "UEFI BIOS found: $UEFI_BIOS"
        BIOS_OPTION="-bios $UEFI_BIOS"
    else
        if [ "$CPU_SUPPORTS_VT" = "no" ]; then
            print_warning "Using legacy BIOS - CPU lacks virtualization support for UEFI"
        else
            print_warning "Using legacy BIOS - OVMF not found or CPU compatibility limited"
        fi
        # Force legacy BIOS mode explicitly
        BIOS_OPTION="-machine pc,accel=kvm:tcg"
    fi

    # Display configuration after boot mode detection
    VM_BOOT_MODE=$([ "$USE_UEFI" = "yes" ] && echo "UEFI" || echo "Legacy BIOS")
    echo
    echo -e "${BRIGHT_CYAN}=================================================================================${NC}"
    echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}                      ${BOLD}INSTALLATION CONFIGURATION${NC}                              ${BRIGHT_CYAN}|${NC}"
    echo -e "${BRIGHT_CYAN}|                                                                               |${NC}"
    echo -e "${BRIGHT_CYAN}|-------------------------------------------------------------------------------|${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}                                                                               ${BRIGHT_CYAN}|${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}VM Boot Mode:${NC}      ${YELLOW}$VM_BOOT_MODE${NC} ${DIM}(for Windows installation)${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}Target Disk:${NC}       ${YELLOW}$TARGET_DISK${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}IP Address:${NC}        ${YELLOW}$SERVER_IP${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}Gateway:${NC}           ${YELLOW}$SERVER_GATEWAY${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}DNS Servers:${NC}       ${YELLOW}185.12.64.1, 185.12.64.2${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}Windows Version:${NC}   ${YELLOW}Server $WINDOWS_VERSION${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}   ${CYAN}Computer Name:${NC}     ${YELLOW}$COMPUTER_NAME${NC}"
    echo -e "${BRIGHT_CYAN}|${NC}                                                                               ${BRIGHT_CYAN}|${NC}"
    echo -e "${BRIGHT_CYAN}=================================================================================${NC}"
    echo
    sleep 3

    # Set acceleration and CPU options based on virtualization support
    if [ "$CPU_SUPPORTS_VT" = "yes" ]; then
        ACCEL_OPTION="-enable-kvm"
        CPU_OPTION="-cpu host"
    else
        ACCEL_OPTION=""
        CPU_OPTION="-cpu qemu64"
        print_warning "Running without KVM acceleration - installation will be slower"
    fi

    if [ -f "$WORK_DIR/autounattend.img" ]; then
        # with floppy
        $QEMU_BIN \
            $BIOS_OPTION \
            $ACCEL_OPTION \
            $CPU_OPTION \
            -m 4096 \
            -smp 4 \
            -drive file=$TARGET_DISK,format=raw,if=ide \
            -drive file="$WORK_DIR/windows_custom.iso",media=cdrom,if=ide \
            -drive file="$WORK_DIR/autounattend.img",if=floppy,format=raw \
            -boot order=d \
            -vnc :1 \
            -daemonize \
            -pidfile "$WORK_DIR/qemu.pid"
    else
        # without floppy
        $QEMU_BIN \
            $BIOS_OPTION \
            $ACCEL_OPTION \
            $CPU_OPTION \
            -m 4096 \
            -smp 4 \
            -drive file=$TARGET_DISK,format=raw,if=ide \
            -drive file="$WORK_DIR/windows_custom.iso",media=cdrom,if=ide \
            -boot order=d \
            -vnc :1 \
            -daemonize \
            -pidfile "$WORK_DIR/qemu.pid"
    fi

    print_success "Virtual machine started successfully"

    # Show installation progress
    echo
    echo -e "${BRIGHT_GREEN}=================================================================================${NC}"
    echo -e "${BRIGHT_GREEN}|                                                                               |${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                    ${BOLD}${YELLOW}*** INSTALLATION IN PROGRESS ***${NC}                         ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|                                                                               |${NC}"
    echo -e "${BRIGHT_GREEN}|-------------------------------------------------------------------------------|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   The automated installation is now running.                                  ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   This process typically takes 10-15 minutes.                                 ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}VNC Access (Optional):${NC}                                                     ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   Server: ${YELLOW}${SERVER_IP}:5901${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}Server Details:${NC}                                                            ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   Computer Name: ${YELLOW}$COMPUTER_NAME${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   Administrator Password: ${BOLD}${YELLOW}$ADMIN_PASSWORD${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}=================================================================================${NC}"
    echo

    # Monitor installation
    if [ -f "$WORK_DIR/qemu.pid" ]; then
        QEMU_PID=$(cat "$WORK_DIR/qemu.pid")
        START_TIME=$(date +%s)

        echo
        echo -e "${CYAN}Monitoring installation progress...${NC}"
        echo

        while true; do
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - START_TIME))
            MINS=$((ELAPSED / 60))
            SECS=$((ELAPSED % 60))

            printf "\r  Installation time: %02d:%02d" $MINS $SECS

            # Check if qemu died
            if ! kill -0 $QEMU_PID 2>/dev/null; then
                echo
                print_success "VM process ended - installation likely complete"
                break
            fi

            # check for windows partition after 10 min
            if [ $ELAPSED -gt 600 ]; then
                # Handle both partition naming schemes
                WIN_PART=""
                if [ "$USE_UEFI" = "yes" ]; then
                    # UEFI uses partition 3
                    if [ -b "${TARGET_DISK}3" ]; then
                        WIN_PART="${TARGET_DISK}3"
                    elif [ -b "${TARGET_DISK}p3" ]; then
                        WIN_PART="${TARGET_DISK}p3"
                    fi
                else
                    # BIOS uses partition 1 (simplified layout)
                    if [ -b "${TARGET_DISK}1" ]; then
                        WIN_PART="${TARGET_DISK}1"
                    elif [ -b "${TARGET_DISK}p1" ]; then
                        WIN_PART="${TARGET_DISK}p1"
                    fi
                fi

                if [ -n "$WIN_PART" ] && [ -b "$WIN_PART" ]; then
                    PART_SIZE=$(blockdev --getsize64 $WIN_PART 2>/dev/null || echo "0")
                    if [ "$PART_SIZE" -gt 5368709120 ]; then
                        echo
                        print_success "Windows partition detected ($(( PART_SIZE / 1073741824 ))GB)"
                        break
                    fi
                fi
            fi

            # timeout at 15min
            if [ $ELAPSED -gt 900 ]; then
                echo
                print_info "Installation timeout reached (15 minutes)"
                break
            fi

            sleep 10
        done

        # kill vm
        echo
        print_info "Stopping virtual machine..."
        kill $QEMU_PID 2>/dev/null || true
        sleep 5
        kill -9 $QEMU_PID 2>/dev/null || true

        print_success "Installation phase completed"
    fi

    # cleanup any remaining qemu
    pkill -f "qemu.*windows_custom.iso" 2>/dev/null || true
    pkill -f "qemu.*$TARGET_DISK" 2>/dev/null || true

    # Final cleanup - wipe work disk completely as requested
    if [ -n "${WORK_DISK:-}" ]; then
        echo
        print_step "Final Cleanup"
        umount /mnt/wininstall 2>/dev/null || true
        wipefs -a -f "$WORK_DISK" 2>/dev/null || true &
        spinner $! "Wiping work disk"
    fi

    # Installation complete
    echo
    echo
    show_banner
    echo
    echo -e "${BRIGHT_GREEN}=================================================================================${NC}"
    echo -e "${BRIGHT_GREEN}|                                                                               |${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}              ${BOLD}${GREEN}*** INSTALLATION COMPLETED SUCCESSFULLY! ***${NC}                   ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|                                                                               |${NC}"
    echo -e "${BRIGHT_GREEN}|-------------------------------------------------------------------------------|${NC}"
    echo -e "${BRIGHT_GREEN}|                                                                               |${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${BOLD}${CYAN}Server Connection Details:${NC}                                                 ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}IP Address:${NC}      ${YELLOW}$SERVER_IP${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}Username:${NC}        ${YELLOW}Administrator${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}Password:${NC}        ${BOLD}${YELLOW}$ADMIN_PASSWORD${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}Computer Name:${NC}   ${YELLOW}$COMPUTER_NAME${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${CYAN}RDP Port:${NC}        ${YELLOW}3389${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|-------------------------------------------------------------------------------|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${BOLD}${CYAN}Next Steps:${NC}                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${GREEN}1.${NC} Reboot your server: ${YELLOW}reboot${NC}                                             ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${GREEN}2.${NC} Wait 2-3 minutes for Windows to start                                   ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}   ${GREEN}3.${NC} Connect via RDP to your server                                          ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}|${NC}                                                                               ${BRIGHT_GREEN}|${NC}"
    echo -e "${BRIGHT_GREEN}=================================================================================${NC}"
    echo

    # Password reminder
    if [ "$USING_DEFAULT_PASSWORD" = true ]; then
        echo -e "${BRIGHT_YELLOW}=================================================================================${NC}"
        echo -e "${BRIGHT_YELLOW}|                                                                               |${NC}"
        echo -e "${BRIGHT_YELLOW}|${NC}                ${BOLD}>>> IMPORTANT: SAVE THIS PASSWORD <<<${NC}                        ${BRIGHT_YELLOW}|${NC}"
        echo -e "${BRIGHT_YELLOW}|${NC}                                                                               ${BRIGHT_YELLOW}|${NC}"
        echo -e "${BRIGHT_YELLOW}|${NC}                    Administrator Password: ${BOLD}$ADMIN_PASSWORD${NC}                     ${BRIGHT_YELLOW}|${NC}"
        echo -e "${BRIGHT_YELLOW}|                                                                               |${NC}"
        echo -e "${BRIGHT_YELLOW}=================================================================================${NC}"
        echo
    fi

    read -p "$(echo -e ${YELLOW}Do you want to reboot the server now? [Y/n]:${NC} )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo -e "\n${CYAN}Rebooting server in 10 seconds...${NC}"
        echo -e "${DIM}Press Ctrl+C to cancel${NC}\n"

        for i in {10..1}; do
            echo -ne "\r${YELLOW}Rebooting in $i seconds... ${NC}"
            sleep 1
        done

        echo -e "\n\n${GREEN}Rebooting now!${NC}"
        cleanup
        sleep 1
        reboot
    else
        echo -e "\n${CYAN}Automatic reboot cancelled.${NC}"
        echo -e "When ready, run: ${YELLOW}reboot${NC}"
    fi

    cleanup
}

# Main execution
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -eq 0 ]; then
        clear
        echo "DigiRDP Windows Server Installer"
        echo "================================="
        echo
        echo "Usage: $0 [IP] [GATEWAY] [VERSION] [PASSWORD]"
        echo
        echo "Examples:"
        echo "  Quick install: $0 auto auto 2022"
        echo "  With password: $0 auto auto 2022 MySecurePass123!"
        echo "  Manual network: $0 192.168.1.100 192.168.1.1 2022"
        echo "  Force legacy BIOS: DISABLE_UEFI=1 $0 auto auto 2022"
        echo
        echo "Default password: DigiRDP2025!"
        echo "Supported versions: 2016, 2019, 2022"
        echo
        echo "Environment variables:"
        echo "  DISABLE_UEFI=1      Force legacy BIOS (disable UEFI/OVMF)"
        echo "  FORCE_LEGACY_BIOS=1 Same as DISABLE_UEFI=1"
        echo
        exit 1
    fi

    # Check and launch in screen if needed
    check_and_launch_screen "$@"

    # If we get here, we're already in screen
    perform_installation "$@"
fi


# Execute installation
perform_installation "$SERVER_IP" "$SERVER_GATEWAY" "$WINDOWS_VERSION" "$ADMIN_PASSWORD"

# Self-destruct
rm -f "$0"
