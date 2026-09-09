#Requires AutoHotkey v2.0
#Warn All, OutputDebug
; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

; ─── Script registry ──────────────────────────────────────────
; Centraliza o registro dos scripts disponíveis; cada módulo declara seus
; próprios handlers nos respectivos registries.

#Include ..\..\lib\modules\remessa_protocolo\RPRegistry.ahk
#Include ..\..\lib\modules\protocolar\ProtocolarRegistry.ahk
#Include ..\..\lib\modules\fechar_xml\FecharXmlRegistry.ahk

global gScripts := [  ; catalog of available scripts — read by InitializeApp() via Dispatcher
    Map(
        "id",        "remessa_protocolo",
        "nome",      "Remessa por Protocolo",
        "categoria", "Faturamento",
        "descricao", "Baixa protocolos no MOV DOC e cria/atualiza remessa no FFCV",
        "params", [
            Map("id","protocolos",     "label","Protocolos",
                "tipo","text",   "obrigatorio",true,
                "hint","Ex: 12345, 67890"),
            Map("id","tipo_conta",     "label","Tipo de Conta",
                "tipo","select", "obrigatorio",true,
                "opcoes",["Internamento","Ambulatório","Emergência"]),
            Map("id","num_remessa",    "label","Remessa Existente",
                "tipo","text",   "obrigatorio",false,
                "hint","Deixe vazio para criar nova"),
            Map("id","data_entrega",   "label","Data de Entrega",
                "tipo","date",   "obrigatorio",false,
                "format","yyyy-MM-dd"),
            Map("id","data_vencimento","label","Data de Vencimento",
                "tipo","date",   "obrigatorio",false,
                "format","yyyy-MM-dd")
        ]
    ),
    Map(
        "id",        "protocolar",
        "nome",      "Protocolar",
        "categoria", "Movimentação",
        "descricao", "Movimenta contas de remessas para outro setor",
        "params", [
            Map("id","remessas",    "label","Número das Remessas",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 511458, 514015"),
            Map("id","setor_atual", "label","Setor Atual",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 34"),
            Map("id","setor_envio", "label","Setor de Envio",
                "tipo","text",  "obrigatorio",true,
                "hint","Ex: 365")
        ]
    ),
    Map(
        "id",        "fechar_xml",
        "nome",      "Fechar e Gerar XML",
        "categoria", "Faturamento",
        "descricao", "Fecha remessas e gera arquivo XML",
        "params", [
            Map("id","remessas",      "label","Número das Remessas",
                "tipo","text", "obrigatorio",true,
                "hint","Ex: 511458, 514015"),
            Map("id","data_entrega",  "label","Data de Entrega",
                "tipo","date", "obrigatorio",true,
                "format","yyyy-MM-dd"),
            Map("id","data_vencimento","label","Data de Vencimento",
                "tipo","date", "obrigatorio",true,
                "format","yyyy-MM-dd")
        ]
    )
]

ValidateScripts(scripts) {
    if !(scripts is Array)
        throw Error("gScripts deve ser Array.")

    ids := Map()
    allowedTypes := Map("text", true, "select", true, "date", true)

    for script in scripts {
        if !(script is Map)
            throw Error("Cada script deve ser Map.")

        for key in ["id", "nome", "categoria", "descricao", "params"] {
            if !script.Has(key)
                throw Error("Script sem campo obrigatorio: " . key)
        }

        id := Trim(script["id"])
        if (id = "")
            throw Error("Script com id vazio.")

        if !RegExMatch(id, "^[a-z0-9_/-]+$")
            throw Error("Script com id malformado: " . id)

        script["id"] := id

        for key in ["nome", "categoria", "descricao"] {
            script[key] := Trim(script[key])
            if (script[key] = "")
                throw Error("Script " . id . " com campo vazio: " . key)
        }

        if ids.Has(id)
            throw Error("ID de script duplicado: " . id)

        ids[id] := true

        if !(script["params"] is Array)
            throw Error("Params deve ser Array no script: " . id)

        paramIds := Map()

        for param in script["params"] {
            if !(param is Map)
                throw Error("Cada param deve ser Map no script: " . id)

            for key in ["id", "label", "tipo", "obrigatorio"] {
                if !param.Has(key)
                    throw Error("Param sem campo obrigatorio em script " . id . ": " . key)
            }

            paramId := Trim(param["id"])
            if (paramId = "")
                throw Error("Param com id vazio em script: " . id)

            if !RegExMatch(paramId, "^[a-z0-9_/-]+$")
                throw Error("Param com id malformado em script " . id . ": " . paramId)

            param["id"] := paramId

            for key in ["label", "tipo"] {
                param[key] := Trim(param[key])
                if (param[key] = "")
                    throw Error("Param " . paramId . " com campo vazio: " . key . " em script: " . id)
            }

            if paramIds.Has(paramId)
                throw Error("Param duplicado em script " . id . ": " . paramId)

            paramIds[paramId] := true

            tipo := Trim(param["tipo"])
            param["tipo"] := tipo

            if !allowedTypes.Has(tipo)
                throw Error("Tipo de param invalido em script " . id . ": " . tipo)

            obrigatorio := param["obrigatorio"]
            if !(obrigatorio = true || obrigatorio = false)
                throw Error("Campo obrigatorio deve ser booleano em script " . id . ": " . paramId)

            if (tipo = "date") {
                if !param.Has("format")
                    throw Error("Param date sem format em script " . id . ": " . paramId)

                param["format"] := Trim(param["format"])

                if (param["format"] != "yyyy-MM-dd")
                    throw Error("Formato date invalido em script " . id . ": " . paramId . " = " . param["format"])
            }

            if (tipo = "select") {
                if !param.Has("opcoes")
                    throw Error("Param select sem opcoes em script " . id . ": " . paramId)

                if !(param["opcoes"] is Array)
                    throw Error("Opcoes deve ser Array em script " . id . ": " . paramId)

                if (param["opcoes"].Length = 0)
                    throw Error("Param select com opcoes vazias em script " . id . ": " . paramId)

                optionSeen := Map()
                for idx, opcao in param["opcoes"] {
                    opcao := Trim(opcao)

                    if (opcao = "")
                        throw Error("Opcao vazia em script " . id . ": " . paramId)

                    if optionSeen.Has(opcao)
                        throw Error("Opcao duplicada em script " . id . ": " . paramId . " = " . opcao)

                    param["opcoes"][idx] := opcao
                    optionSeen[opcao] := true
                }
            }
        }
    }
}

if (gScripts.Length = 0)
    throw Error("Nenhum script registrado. Verifique os arquivos de modulo.")

ValidateScripts(gScripts)
