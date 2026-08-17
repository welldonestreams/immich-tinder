; Immich Tinder - custom uninstall cleanup
; Removes everything the app leaves behind:
;   - SmartScreen / AppCompat registry flags (Windows marks new/unsigned exes)
;   - Prefetch leftovers
;   - The app folder itself

!macro customUnInstall
  ; --- SmartScreen / AppCompat flags for this app's exe ---
  ; Windows writes a value like "<exe path> - 53 41 43 50 31 0" under
  ; AppCompatFlags\Compatibility Assistant\Store when SmartScreen flags the
  ; app. The value name varies per machine, so match by prefix.
  StrLen $3 "$INSTDIR\${APP_EXECUTABLE_FILENAME}"
  StrCpy $0 0
  StoreLoop:
    EnumRegValue $1 HKCU "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" $0
    StrCmp $1 "" StoreDone
    StrCpy $4 $1 $3
    StrCmp $4 "$INSTDIR\${APP_EXECUTABLE_FILENAME}" 0 StoreNext
    DeleteRegValue HKCU "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" $1
    StoreNext:
    IntOp $0 $0 + 1
    Goto StoreLoop
  StoreDone:
  DeleteRegValue HKCU "Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" "$INSTDIR\${APP_EXECUTABLE_FILENAME}"

  ; --- Prefetch leftovers ---
  Delete "$WINDIR\Prefetch\IMMICH TINDER.EXE-*.pf"
  Delete "$WINDIR\Prefetch\UNINSTALL IMMICH TINDER.EXE-*.pf"

  ; --- App folder (in-use files are deferred by NSIS itself) ---
  RMDir /r "$INSTDIR"
!macroend
