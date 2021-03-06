
<#PSScriptInfo

.VERSION 1.0

.GUID 8e37e603-aa7a-4cf8-ac7e-c5a9ef3f3769

.AUTHOR Konstantin N. aka pardusurbanus@protonmail.com

.COMPANYNAME urbanus.tech

.TAGS build, suricata, windows

.LICENSEURI https://github.com/unuaunco/suricata-win-build/blob/main/LICENSE

.PROJECTURI https://github.com/unuaunco/suricata-win-build

.RELEASENOTES
 First encounter.

#>

<# 

.DESCRIPTION 
 The Script is for building Suricata 6.0.2 from sources. 
 Installs msys2 packages and various dependencies. 
 Tested on Windows 10 v 20H2 (OS Build 19042.1052). 

#> 
Param()

$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

function Install-7z{
  <#
  .SYNOPSIS
      Installs 7z archive.
  .DESCRIPTION
      Function is intend to install 7z
  .PARAMETER DownloadUrl
      Link to download 7zip installator. 
      Default: 'https://7-zip.org/a/7z1900-x64.exe'
  .EXAMPLE
      Install-7z
  #>
  [CmdletBinding()]
  Param ( 
      [Parameter(Mandatory=$false)] 
      [Alias('DownloadUrl')] 
      [string]$Url='https://7-zip.org/a/7z1900-x64.exe'
  ) 
  process{
    $env:Path+= ";$($env:PROGRAMFILES)\7-Zip"
    $is7zipInstalled = [boolean]$($(Start-Job -ScriptBlock {7z.exe i} | Wait-Job).State -eq "Completed")
    if (-not $is7zipInstalled){
        Invoke-WebRequest $Url -OutFile "$($env:TEMP)\7z_install.exe"
        Start-Job -ScriptBlock {&"$($env:TEMP)\7z_install.exe" /S /D="$($env:PROGRAMFILES)\7-Zip"}  | Wait-Job
        
        $is7zipInstalled = [boolean]$($(Start-Job -ScriptBlock {7z.exe i} | Wait-Job).State -eq "Completed")

        if (-not $is7zipInstalled){
            Write-Error -Message "7zip installation is unsuccessful"
            [System.Environment]::Exit(1)
        }

        Remove-Item "$($env:TEMP)\7z_install.exe"

        Write-Host "7zip installed successfully"
    }
    else {
        Write-Host "7zip already installed"
    }
  }
}

Install-7z -Url 'https://7-zip.org/a/7z1900-x64.exe'

Invoke-WebRequest http://repo.msys2.org/distrib/x86_64/msys2-base-x86_64-20210604.tar.xz `
    -OutFile "$($env:TEMP)\msys2.tar.xz"

7z.exe x "$($env:TEMP)\msys2.tar.xz" -o"$($env:TEMP)\" -y

7z.exe x "$($env:TEMP)\msys2.tar" -o"$($env:SystemDrive)" -y

$env:Path += ";$($env:SystemDrive)\msys64"

msys2_shell.cmd -defterm -no-start -here -mingw64 -c "yes | pacman -Syuu"

msys2_shell.cmd -defterm -no-start -here -mingw64 -c $(@"
yes | pacman -S --noconfirm --needed base-devel \
mingw-w64-x86_64-toolchain subversion
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c $(@"
yes | pacman -S --noconfirm \
mingw64/mingw-w64-x86_64-libtool mingw64/mingw-w64-x86_64-pcre \
mingw64/mingw-w64-x86_64-lua mingw64/mingw-w64-x86_64-geoip \
mingw64/mingw-w64-x86_64-luajit-git wget jansson  jansson-devel libpcre pcre \
pcre-devel gcc  gcc-libs  make autoconf autogen automake git libyaml \
libyaml-devel zlib zlib-devel pkg-config mingw64/mingw-w64-x86_64-nspr \
mingw64/mingw-w64-x86_64-nss mingw64/mingw-w64-x86_64-rust \
mingw64/mingw-w64-x86_64-python3-yaml mingw64/mingw-w64-x86_64-jansson \
msys/jansson-devel msys/jansson mingw-w64-x86_64-toolchain automake1.16 \
automake-wrapper autoconf libtool libyaml-devel pcre-devel jansson-devel \
make mingw-w64-x86_64-libyaml mingw-w64-x86_64-pcre mingw-w64-x86_64-rust \
mingw-w64-x86_64-jansson unzip p7zip python-setuptools mingw-w64-x86_64-python-yaml \
mingw-w64-x86_64-jq mingw-w64-x86_64-libxml2
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c $(@"
mkdir /npcap-sdk \
&& curl -O https://nmap.org/npcap/dist/npcap-sdk-1.07.zip \
&& unzip npcap-sdk-1.07.zip -d /npcap-sdk
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c  $(@"
git clone -b suricata-6.0.2 https://github.com/OISF/suricata.git \
&& cd suricata \
&& git clone https://github.com/OISF/libhtp.git -b 0.5.x
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c  $(@"
cd suricata \
&& cargo install cbindgen
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c  $(@"
curl -s -O https://nmap.org/npcap/dist/npcap-1.00.exe \
&& 7z -y x -o/npcap-bin npcap-1.00.exe && cp /npcap-bin/*.dll ./suricata
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c  $(@"
cd suricata \
&& export PATH=`$PATH:/c/Users/$env:USERNAME/.cargo/bin \
&& ./autogen.sh \
&& ./configure \
--with-libpcap-includes=/npcap-sdk/Include/ --with-libpcap-libraries=/npcap-sdk/Lib/x64/ \
--with-libnss-libraries=/mingw64/lib/ --with-libnss-includes=/mingw64/include/nss3/ \
--with-libnspr-libraries=/mingw64/lib/ --with-libnspr-includes=/mingw64/include/nspr/ \
--enable-lua --disable-gccmarch-native --enable-gccprotect \
&& make clean \
&& make -j 2
"@ -replace "\\`n"," ")

msys2_shell.cmd -defterm -no-start -mingw64 -here -c  $(@"
mkdir -p /c/Program\ files/Suricata/{log,rules} \
&& cd suricata \
&& cp ./src/.libs/suricata.exe /c/Program\ files/Suricata \
&& cp ./suricata.yaml /c/Program\ files/Suricata \
&& cp ./rules/*.rules /c/Program\ files/Suricata/rules \
&& cp ./threshold.config /c/Program\ files/Suricata \
&& cp /c/msys64/mingw64/bin/{libGeoIP-1.dll,libssp-0.dll,libjansson-4.dll,libwinpthread-1.dll,\
liblzma-5.dll,libyaml-0-2.dll,libnspr4.dll,lua54.dll,libpcre-1.dll,nss3.dll,libplc4.dll,\
nssutil3.dll,libplds4.dll,zlib1.dll} /c/Program\ files/Suricata
"@ -replace "\\`n","")
