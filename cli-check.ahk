; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; CLI entry point: runs integrity check and exits (dev mode helper).
; Usage: AutoHotkey64.exe cli-check.ahk [--check]
;
; Este arquivo é para dev mode (raiz do repositório). Ele NÃO é distribuído:
; o Praxis.exe compilado executa IntegrityDoCheck() internamente com o
; manifesto embutido — ver main.ahk e lib/app/IntegrityCheck.ahk.

#Requires AutoHotkey v2.0
#Warn All, OutputDebug
#SingleInstance Force

; AppState.ahk ANTES do manifesto: o manifesto reatribui
; gIntegrityExpectedFiles e precisa que AppState.ahk ja tenha
; declarado o Map como global. Mesmo motivo documentado em main.ahk.
#Include lib\app\AppState.ahk
#Include *i build\generated\Praxis_IntegrityManifest.ahk
#Include lib\app\IntegrityCheck.ahk

IntegrityDoCheck()
ExitApp 0