; The name of the installer
Name "Rossignol"

; The file to write
OutFile "install.exe"

; The default installation directory
InstallDir $PROGRAMFILES\Rossignol

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\Rossignol" "Install_Dir"

; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------

; Pages

Page components
Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

;--------------------------------

; The stuff to install
Section "Rossignol (required)"

  SectionIn RO
  
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  
  ; Put file there
  File "install.nsi"
  File /r "doc\*.pdf"
  File "img\16x16\document-new.png"
  File "img\16x16\feed.png"
  File "img\16x16\folder.png"
  File "img\16x16\folder-new.png"
  File "img\16x16\folder-open.png"
  File "img\16x16\process-working.png"
  File "img\16x16\view-refresh.png"
  File "img\rossignol.png"
  File "libcurl.dll"
  File "license.txt"
  File "Rossignol.exe"
  File "zlib1.dll"
  
  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\Rossignol "Install_Dir" "$INSTDIR"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rossignol" "DisplayName" "Rossignol"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rossignol" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rossignol" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rossignol" "NoRepair" 1
  WriteUninstaller "uninstall.exe"
  
SectionEnd

; Optional section (can be disabled by the user)
Section "Start Menu Shortcuts"

  CreateDirectory "$SMPROGRAMS\Rossignol"
  CreateShortCut "$SMPROGRAMS\Rossignol\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  CreateShortCut "$SMPROGRAMS\Rossignol\Rossignol.lnk" "$INSTDIR\rossignol.exe"
  
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Rossignol"
  DeleteRegKey HKLM SOFTWARE\Rossignol

  ; Remove files and uninstaller
  Delete $INSTDIR\install.nsi
  Delete $INSTDIR\uninstall.exe

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\Rossignol\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\Rossignol"
  RMDir "$INSTDIR"

SectionEnd
