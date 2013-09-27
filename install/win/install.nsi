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
  File /r "doc"
  File /r "img"
  File /r "lang"
  File "libcurl.dll"
  File "license.txt"                                                                       
  File "Rossignol.exe"
  File "Rossignol.exe.manifest"
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
  Delete "$INSTDIR\doc\*.*"
  RMDir "$INSTDIR\doc"
  Delete "$INSTDIR\lang\*.*"
  RMDir "$INSTDIR\lang"
  Delete "$INSTDIR\img\16x16\*.*"
  RMDir "$INSTDIR\img\16x16"
  Delete "$INSTDIR\img\*.*"
  RMDir "$INSTDIR\img"
  Delete "$INSTDIR\*.*"
  
  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\Rossignol\*.*"

  ; Remove directories used
  RMDir "$SMPROGRAMS\Rossignol"
  RMDir "$INSTDIR"

SectionEnd
