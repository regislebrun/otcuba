; 
; Setup script in order to create a windows auto-installer for OpenTURNS module.
;
; To lauch the creation of the installer :
;   makensis  -DMODULE_PREFIX=/absolute/path -DMODULE_VERSION=1.0 -DOPENTURNS_VERSION=1.0 installer.nsi
;

SetCompressor /SOLID lzma

RequestExecutionLevel user

; Prefix where module is installed on Linux.
!ifndef MODULE_PREFIX
  !error "MODULE_PREFIX must be defined"
!endif

!ifndef ARCH
  !error "ARCH must be defined"
!endif

!include "WordFunc.nsh" ; for ${WordAdd}, ${WordReplace}
!include "FileFunc.nsh" ; for ${DirState} , ${GetParent}, ${ConfigWrite}, ${GetFileAttributes}
!include "TextFunc.nsh" ; for ${ConfigRead}
!include "LogicLib.nsh" ; for ${If}

!define MODULE_NAME OTTemplate
!define MODULE_NAME_LOWERCASE ottemplate

; Script generated by the HM NIS Edit Script Wizard.
; HM NIS Edit Wizard helper defines
!ifndef MODULE_VERSION
  !error "MODULE_VERSION must be defined"
!endif
!define PRODUCT_VERSION ${MODULE_VERSION}

!ifndef OPENTURNS_VERSION
  !error "OPENTURNS_VERSION must be defined"
!endif
!define PRODUCT_NAME "${MODULE_NAME}"
!define PRODUCT_WEB_SITE "http://www.openturns.org"
!define OT_PRODUCT_DIR_REGKEY "Software\OpenTURNS"
!define PRODUCT_DIR_REGKEY "Software\OpenTURNS\${MODULE_NAME}"
!define PRODUCT_INST_ROOT_KEY "HKLM"

!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OpenTURNS\${MODULE_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; MUI 1.67 compatible ------
!include "MUI.nsh"

; MUI Settings
!define MUI_ABORTWARNING

; Language Selection Dialog Settings
!define MUI_LANGDLL_REGISTRY_ROOT "${PRODUCT_UNINST_ROOT_KEY}"
!define MUI_LANGDLL_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "NSIS:Language"

; Welcome page
!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation of ${PRODUCT_NAME} ${PRODUCT_VERSION}.\r\rThis installer has been tested on Windows 2000, XP and Vista. Although OpenTURNS may work on it, other operating systems are not supported."
!insertmacro MUI_PAGE_WELCOME
; License page
;!insertmacro MUI_PAGE_LICENSE "COPYING.txt"
; Components page
!insertmacro MUI_PAGE_COMPONENTS
; Directory page
!define MUI_DIRECTORYPAGE_TEXT_TOP "Setup will install ${PRODUCT_NAME} ${PRODUCT_VERSION} in the following folder. To install in a different folder, click Browse and select another folder."
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Finish page
!define MUI_FINISHPAGE_TEXT "${PRODUCT_NAME} ${PRODUCT_VERSION} has been installed on your computer.\r\rSee README-${MODULE_NAME}.txt for further explanation."
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; MUI end ------

Name "${MODULE_NAME} ${PRODUCT_VERSION}"
OutFile "${MODULE_NAME_LOWERCASE}-${PRODUCT_VERSION}-py${PYBASEVER}-${ARCH}.exe"
!define UNINST_EXE "uninst-${MODULE_NAME_LOWERCASE}.exe"
Var MODULE_INSTALL_PATH
!define Python_default_INSTALL_PATH "C:\Python${PYBASEVER_NODOT}"
InstallDir "${Python_default_INSTALL_PATH}\"
ShowInstDetails show
ShowUnInstDetails show

Var Python_INSTALL_PATH 

!macro CHECK_REG_VIEW
  ${If} "${ARCH}" == "x86_64"
     SetRegView 64
  ${EndIf}
!macroend


!macro PRINT MSG
  SetDetailsPrint both
  DetailPrint "${MSG}"
  SetDetailsPrint none
!macroend


Var UserInstall

; Check that current user has administrator privileges 
; if ok : set UserInstall to 0, if not : set UserInstall to 1
!macro CHECK_USER_INSTALL WARN_MSG
  StrCpy $UserInstall "0"

  ; avoid check if /userlevel option is present on command line
  ${GetParameters} $R1
  ClearErrors
  ${GetOptions} $R1 '/userlevel=' $R0
  IfErrors 0 set_level

  ClearErrors
  WriteRegStr ${PRODUCT_INST_ROOT_KEY} ${PRODUCT_DIR_REGKEY} "Test" "${PRODUCT_VERSION}"
  IfErrors user_install admin_install
  user_install:
  StrCpy $UserInstall "1"
  MessageBox MB_OK|MB_ICONINFORMATION "You are not running Windows from an administrator account.$\r$\rTo enable admin rights on Windows Vista and above: right click on the installer, choose 'Run as administrator'.$\r$\r${WARN_MSG}" /SD IDOK
  admin_install:
  DeleteRegValue ${PRODUCT_INST_ROOT_KEY} ${PRODUCT_DIR_REGKEY} "Test"
  Goto end_set_level

  set_level:
  StrCpy $UserInstall $R0
  end_set_level:
!macroend


!macro CHECK_USER_INSTALL_FILE FILE_NAME
  ; Get previous installation mode
  IfFileExists "${FILE_NAME}" user_mode 0
  StrCpy $UserInstall "0"
  Goto end_user_mode
  user_mode:
  StrCpy $UserInstall "1"
  end_user_mode:

  ${If} "$UserInstall" == "0"
    !insertmacro CHECK_USER_INSTALL "Uninstall from a non-administrator could not work cause you installed ${PRODUCT_NAME} from an admin account."
  ${EndIf}
!macroend


!macro CREATE_USER_INSTALL_FILE FILE_NAME
  ; create a file for uninstaller
  FileOpen $0 "${FILE_NAME}" w
  IfErrors userfile_fail
  FileWrite $0 "${PRODUCT_NAME} was installed in user mode."
  FileClose $0
  userfile_fail:
!macroend


; Set whether OpenTURNS shortcuts will be in every user menu or only in current user menu.
; CHECK_USER_INSTALL must have been called first
!macro SET_MENU_CONTEXT
  ${If} "$UserInstall" == "0"
    SetShellVarContext all
  ${Else}
    SetShellVarContext current
  ${EndIf}
!macroend


; set $Python_INSTALL_PATH to python dir found
Function CheckPython
  ClearErrors

  ; user set the python path
  ${If} $INSTDIR != "${Python_default_INSTALL_PATH}"
    StrCpy $Python_INSTALL_PATH "$INSTDIR"
  ${Else}
    ; search the prog in the Windows registry
    ReadRegStr $Python_INSTALL_PATH HKLM "Software\Python\PythonCore\${PYBASEVER}\InstallPath" ""
    ${If} $Python_INSTALL_PATH == ""
      !insertmacro PRINT "! Python not found in machine registry, try user registry."
      ReadRegStr $Python_INSTALL_PATH HKCU "Software\Python\PythonCore\${PYBASEVER}\InstallPath" ""
    ${EndIf}

    ${If} $Python_INSTALL_PATH == ""
      !insertmacro PRINT "! Python not found in registry, try default directory (${Python_default_INSTALL_PATH}) ."
      StrCpy $Python_INSTALL_PATH "${Python_default_INSTALL_PATH}"
    ${EndIf}
  ${EndIf}

  ; Check that the python exe is there
  IfFileExists "$Python_INSTALL_PATH\python.exe" 0 python_not_found_error
    !insertmacro PRINT "=> Python found here: $Python_INSTALL_PATH."
  Goto python_not_found_error_end
  python_not_found_error:
    StrCpy $Python_INSTALL_PATH ""
    !insertmacro PRINT "! Python not found !"
  python_not_found_error_end:

FunctionEnd


; set $Python_INSTALL_PATH to python dir found
Function CheckOpenturns
  ClearErrors

  ; user set the python path
  ${If} $INSTDIR != "${Python_default_INSTALL_PATH}"
    StrCpy $Python_INSTALL_PATH "$INSTDIR"
  ${Else}

    ; Find where OT is installed
    ReadRegStr $0 ${PRODUCT_INST_ROOT_KEY} "${OT_PRODUCT_DIR_REGKEY}" "InstallPath"
    ${If} $0 != ""
      ReadRegStr $1 ${PRODUCT_INST_ROOT_KEY} "${OT_PRODUCT_DIR_REGKEY}" "Current Version"
      !insertmacro PRINT "Found OpenTURNS $1 in directory $0."

      ${If} $1 == "${OPENTURNS_VERSION}"
        !insertmacro PRINT "OpenTURNS version is ok."
      ${Else}
        !insertmacro PRINT "OpenTURNS version is not the recommended one!"
      ${EndIf}

      ; Find python prefix
      ${GetParent} $0 $0
      ${GetParent} $0 $0
      ${GetParent} $0 $Python_INSTALL_PATH

    ${Else}
      !insertmacro PRINT "! OpenTURNS not found in registry, try to find python directory"
      Call CheckPython
    ${EndIf}
  ${EndIf}

  ; Check that the python exe is there
  IfFileExists "$Python_INSTALL_PATH\python.exe" 0 python_not_found_error
    !insertmacro PRINT "=> Python found here: $Python_INSTALL_PATH."
  Goto python_not_found_error_end
  python_not_found_error:
    StrCpy $Python_INSTALL_PATH ""
    !insertmacro PRINT "! Python not found !"
  python_not_found_error_end:

FunctionEnd







; Launched before the section are displayed
Function .onInit
  !insertmacro CHECK_REG_VIEW

  !insertmacro MUI_LANGDLL_DISPLAY

  !insertmacro CHECK_USER_INSTALL "Installation from a non-administrator account is not supported although it may works."

  SetDetailsPrint both


  Call CheckOpenturns

  ${If} $Python_INSTALL_PATH == ""
    MessageBox MB_OK|MB_ICONEXCLAMATION "Python ${PYBASEVER} installation directory not found!$\rEnter manually the Python installation directory." /SD IDOK
    ; abort if silent install and not FORCE flag
    IfSilent 0 end_abort
    ${GetParameters} $R1
    ClearErrors
    ${GetOptions} $R1 '/FORCE' $R0
    IfErrors 0 +2
    Abort
    end_abort:
  ${Else} 
    ; if there is a \ at the end of Python_INSTALL_PATH: remove it
    StrCpy $0 "$Python_INSTALL_PATH" "" -1
    ${if} $0 == "\" 
      StrCpy $0 "$Python_INSTALL_PATH" -1
      StrCpy $Python_INSTALL_PATH "$0"
    ${EndIf}

    StrCpy $INSTDIR "$Python_INSTALL_PATH"
    StrCpy $MODULE_INSTALL_PATH "$Python_INSTALL_PATH\Lib\site-packages\${MODULE_NAME_LOWERCASE}"
    ; MessageBox MB_OK|MB_ICONEXCLAMATION "Python found in $Python_INSTALL_PATH." /SD IDOK
    ; !insertmacro PRINT "Python $PYBASEVER found in directory $Python_INSTALL_PATH."
  ${EndIf}

  ; if already installed, uninstall previous.
  ReadRegStr $0 ${PRODUCT_INST_ROOT_KEY} "${PRODUCT_DIR_REGKEY}" "${MODULE_NAME}"
  ${If} $0 != ""
    MessageBox MB_YESNO|MB_ICONEXCLAMATION "${MODULE_NAME} $0 is already installed in directory $MODULE_INSTALL_PATH.$\rDo you want to uninstall this installed version (recommended)?" /SD IDYES IDNO skip_uninstall

    ; copy uninstaller to temp dir in order to erase the whole ot dir
    ; _? option permit to avoid uninstaller to copy itself to tempdir. it permit too to make ExecWait work
    CopyFiles "$MODULE_INSTALL_PATH\${UNINST_EXE}" $TEMP
    IfSilent 0 +3
    ; silent uninstall
    ExecWait '"$TEMP\${UNINST_EXE}" /S _?=$MODULE_INSTALL_PATH'
    Goto +2
    ExecWait '"$TEMP\${UNINST_EXE}" _?=$MODULE_INSTALL_PATH'

    skip_uninstall:
  ${EndIf}

  SetDetailsPrint none
  SetAutoClose false
FunctionEnd


Section "!${MODULE_NAME} DLL & doc" SEC01
  SetOverwrite on

  ; reread $INSTDIR in case user change it.
  StrCpy $Python_INSTALL_PATH "$INSTDIR"
  StrCpy $MODULE_INSTALL_PATH "$Python_INSTALL_PATH\Lib\site-packages\${MODULE_NAME_LOWERCASE}"

  SetDetailsPrint both
  ClearErrors
  CreateDirectory "$MODULE_INSTALL_PATH"
  IfErrors permisssion_nok permission_ok
  permisssion_nok:
  !insertmacro PRINT "Failed to create ${PRODUCT_NAME} directory $MODULE_INSTALL_PATH!"
  MessageBox MB_OK|MB_ICONEXCLAMATION "Failed to create ${PRODUCT_NAME} directory $MODULE_INSTALL_PATH!$\rCheck directory permission.$\rInstallation aborted." /SD IDOK
  Abort
  permission_ok:
  SetDetailsPrint none

  !insertmacro PRINT "Install binary files in $MODULE_INSTALL_PATH."
  SetOutPath "$MODULE_INSTALL_PATH"
  File /r "${MODULE_PREFIX}\bin\*.*"
  ; ! not working: __init__ will override  ot __init__
  File /r "${MODULE_PREFIX}\Lib\site-packages\${MODULE_NAME_LOWERCASE}\*.*"
  SetOutPath "$MODULE_INSTALL_PATH\include\${MODULE_NAME_LOWERCASE}"
  File /r "${MODULE_PREFIX}\include\${MODULE_NAME_LOWERCASE}\*.*"

  SetOutPath "$MODULE_INSTALL_PATH"
  File "README.txt"

  ;!insertmacro PRINT "Install doc example in $MODULE_INSTALL_PATH\doc\pdf."
  ;SetOutPath "$MODULE_INSTALL_PATH\doc\pdf"
  ;File "${MODULE_PREFIX}\share\doc\${MODULE_NAME_LOWERCASE}\pdf\${MODULE_NAME}_Documentation.pdf"

  ; create a version file
  ClearErrors
  FileOpen $0 $MODULE_INSTALL_PATH\share\openturns\VERSION-${MODULE_NAME}.txt w
  IfErrors versionfile_fail
  FileWrite $0 "${PRODUCT_NAME} ${PRODUCT_VERSION}"
  FileWrite $0 "Compiled for OpenTURNS ${OPENTURNS_VERSION}"
  FileClose $0
  versionfile_fail:

  !insertmacro PRINT "Put OpenTURNS ${MODULE_NAME} in windows registry."
  WriteRegStr ${PRODUCT_INST_ROOT_KEY} ${PRODUCT_DIR_REGKEY} "${MODULE_NAME}" "${PRODUCT_VERSION}"

  !insertmacro PRINT "Install uninstaller in $MODULE_INSTALL_PATH\${UNINST_EXE}."
  WriteUninstaller "$MODULE_INSTALL_PATH\${UNINST_EXE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$MODULE_INSTALL_PATH\${UNINST_EXE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
SectionEnd


Section "${MODULE_NAME} python examples" SEC02
  SetOverwrite on

  !insertmacro PRINT "Install Python examples in $MODULE_INSTALL_PATH\examples."
  SetOutPath "$MODULE_INSTALL_PATH\examples"
  File "${MODULE_PREFIX}\share\${MODULE_NAME_LOWERCASE}\examples\*.py"
  File "${MODULE_PREFIX}\share\${MODULE_NAME_LOWERCASE}\examples\*.cxx"
SectionEnd


Section -AdditionalIcons
  !insertmacro PRINT "Create OpenTURNS ${MODULE_NAME_LOWERCASE} menu."
  ; install shortcuts on every accounts
  !insertmacro SET_MENU_CONTEXT

  CreateDirectory "$SMPROGRAMS\OpenTURNS\${MODULE_NAME}"
  CreateShortCut "$SMPROGRAMS\OpenTURNS\${MODULE_NAME}\README.lnk" "$MODULE_INSTALL_PATH\README.txt" "" "" 0
  CreateShortCut "$SMPROGRAMS\OpenTURNS\${MODULE_NAME}\Documentation.lnk" "$MODULE_INSTALL_PATH\doc\pdf\${MODULE_NAME}_Documentation.pdf" "" "" 1
  CreateShortCut "$SMPROGRAMS\OpenTURNS\${MODULE_NAME}\Uninstall.lnk" "$MODULE_INSTALL_PATH\${UNINST_EXE}" "" "" 2
SectionEnd


; Section descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${SEC01} "${MODULE_NAME} DLL, headers and doc."
!insertmacro MUI_DESCRIPTION_TEXT ${SEC02} "${MODULE_NAME} python examples."
!insertmacro MUI_FUNCTION_DESCRIPTION_END


Function un.onInit
  !insertmacro MUI_UNGETLANGUAGE

  ; Get previous installation mode
  !insertmacro CHECK_USER_INSTALL_FILE "$MODULE_INSTALL_PATH\UserInstall"

  MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Do you want to remove the module $(^Name) from directory $INSTDIR?" /SD IDYES IDYES +2
  Abort
FunctionEnd


Section Uninstall
  ; nsis can't delete current directory
  SetOutPath $TEMP

  ;SetDetailsPrint both
  RMDir /R $INSTDIR

  !insertmacro SET_MENU_CONTEXT
  RMDir /r "$SMPROGRAMS\OpenTURNS\${MODULE_NAME}"
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"
  DeleteRegKey ${PRODUCT_INST_ROOT_KEY} "${PRODUCT_DIR_REGKEY}"


  SetAutoClose false

SectionEnd

