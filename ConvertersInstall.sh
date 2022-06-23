#!/bin/bash
SCRIPTPATH=$(dirname $(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0))
OWNER=$(stat -c '%U' $SCRIPTPATH)
UPDATE=false
# USERID=$(id -u $OWNER)
# export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USERID/bus";

cecho(){
    RED="\033[0;31m"
    GREEN="\033[0;32m"  # <-- [0 is not bold
    YELLOW="\033[1;33m" # <-- [1 is bold
    CYAN="\033[1;36m"
    NC="\033[0m" # No Color
    printf "${!1}${2} ${NC}\n";
}

recho(){
    if [[ $? -eq 0 ]]; then
        cecho "GREEN" "Done!"
    else
        cecho "RED" "Operation failed. Exiting script.."; exit 1;
    fi
}

if [ "$EUID" -ne 0 ]; then 
    cecho "RED" "Please run as root!"; exit 1;
fi

DISTRO=$(lsb_release -sc) # Get codename. Supports uma, focal and jammy
if [[ "${DISTRO}" != @(uma|focal|jammy) ]]; then
    cecho "RED" "Distro not supported. Exiting script.."; exit 1;
fi     

cecho "CYAN" "Installing script essentials if missing..";
dpkg -s curl 2>/dev/null >/dev/null || apt-get -y install curl;
dpkg -s ca-certificates 2>/dev/null >/dev/null || apt-get -y install ca-certificates;
dpkg -s apt-transport-https 2>/dev/null >/dev/null || apt-get -y install apt-transport-https;
recho $?;

if [ $(cat /etc/apt/sources.list | grep -c "https://download.onlyoffice.com/repo/debian") -eq 0 ]; then
    cecho "CYAN" "Adding Onlyoffice repo..";
    curl -sSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xe09ca29f6e178040ef22b4098320ca65cb2de8e5' | apt-key add -;
    echo "deb https://download.onlyoffice.com/repo/debian squeeze main" >> /etc/apt/sources.list; 
    recho $?;
    if [[ $? -eq 0 ]]; then UPDATE=true; fi  
fi
    
if [ $(cat /etc/apt/sources.list | grep -c "repos/CollaboraOnline/CODE-ubuntu") -eq 0 ]; then    
    cecho "CYAN" "Adding Collabora Office repo..";
    CODE=2004
    if [[ $DISTRO = jammy ]]; then CODE=2204; fi 
    echo "deb https://www.collaboraoffice.com/repos/CollaboraOnline/CODE-ubuntu${CODE} ./" >> /etc/apt/sources.list;
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0C54D189F4BA284D;
    recho $?;
    if [[ $? -eq 0 ]]; then UPDATE=true; fi  
fi

if [ $(cat /etc/apt/sources.list | grep -c "https://www.itforarchivists.com/") -eq 0 ]; then    
    cecho "CYAN" "Adding Siegfried repo..";
    curl -sL "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x20F802FE798E6857" | gpg --dearmor > /usr/share/keyrings/siegfried-archive-keyring.gpg;
    echo "deb [signed-by=/usr/share/keyrings/siegfried-archive-keyring.gpg] https://www.itforarchivists.com/ buster main" >> /etc/apt/sources.list;
    recho $?;
    if [[ $? -eq 0 ]]; then UPDATE=true; fi  
fi

if [[ "$UPDATE" = true ]]; then 
    cecho "CYAN" "Updating repo info..";
    apt-get update; 
    recho $?;
fi    

cecho "CYAN" "Installing apt-gettable dependencies..";
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections;
apt-get install -y ttf-mscorefonts-installer pandoc abiword sqlite3 uchardet \
python3-wheel dos2unix ghostscript onlyoffice-desktopeditors onlyoffice-documentbuilder \
icc-profiles-free clamtk tesseract-ocr clamav-daemon clamav-unofficial-sigs \
clamdscan libclamunrar9 wimtools wkhtmltopdf ruby-dev  imagemagick cabextract fontforge \
python3-pgmagick graphicsmagick graphviz img2pdf golang coolwsd code-brand siegfried;
recho $?;

if [[ $UPDATE = true ]]; then 
    cecho "CYAN" "Configuring Collabora Office..";
    coolconfig set ssl.enable false;
    coolconfig set ssl.termination true;
    systemctl enable coolwsd;    
    systemctl restart coolwsd;  
    # Test: curl --insecure -F "data=@test.docx" http://localhost:9980/lool/convert-to/pdf > out.pdf    
    recho $?;
fi    

cecho "CYAN" "Enable clamav..";
systemctl enable clamav-daemon;
systemctl start clamav-daemon;
recho $?;

cecho "CYAN" "Install mail converter..";
gem install eml_to_pdf;
recho $?;

cecho "CYAN" "Fix fuse permissions..";
sed -i -e 's/#user_allow_other/user_allow_other/' /etc/fuse.conf;
recho $?;

if [ -f "/etc/ImageMagick-6/policy.xml" ]; then
    cecho "CYAN" "Fix pdf permissions for ImageMagick.."
    mv /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xmlout  2>/dev/null;
    recho $?;
fi

if [ $(fc-list | grep -c Calibri) -eq 0 ]; then
    cecho "CYAN" "Installing microsoft fonts..";
    export ACCEPT_EULA=true;
    curl -Ls https://raw.githubusercontent.com/metanorma/vista-fonts-installer/master/vista-fonts-installer.sh | bash;
    recho $?;
fi

# cecho "CYAN" "Install or update python dependencies.."
# sudo -H -u $OWNER bash -c "pip3 install pdfy cchardet petl ocrmypdf --upgrade;";
# recho $?
# cd $SCRIPTPATH;

