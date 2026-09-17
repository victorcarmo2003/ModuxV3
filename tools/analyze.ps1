<#
.SYNOPSIS
    Varre o projeto com o luau-lsp, fora do Roblox Studio.

.DESCRIPTION
    Roda o MESMO motor do editor sobre os arquivos REAIS, usando o sourcemap do
    Rojo para resolver `require(ReplicatedStorage...)` e as definitions do
    Roblox para conhecer `Instance`, `CFrame` e afins.

    A versao anterior montava um espelho plano com os require reescritos. Isso
    parou de funcionar quando a arvore cresceu: com Classes em tres lugares e
    Manifest em dois, os nomes colidiam e o espelho inventava erro em arquivo
    correto. Sourcemap resolve pelo caminho de verdade, sem copiar nada.

    Saida vazia NAO prova nada sozinha: quebre de proposito e confirme que
    acusa, senao voce tem silencio em vez de tipagem.

.PARAMETER Filter
    Analisa so os arquivos cujo caminho bate com esse curinga.

.PARAMETER Detail
    Mostra as mensagens em vez so da contagem.

.NOTES
    Precisa do rojo (rokit add rojo-rbx/rojo) e da extensao luau-lsp instalada.
#>
param(
    [string]$Src    = "src",
    [string]$Filter = "*",
    [string]$Defs   = "",
    [switch]$Detail
)

$ErrorActionPreference = "Stop"

# --- motor e definitions ----------------------------------------------------
if (-not $Defs) {
    $candidatos = @(
        "$env:APPDATA/Code/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau",
        "$env:APPDATA/Antigravity/User/globalStorage/johnnymorganz.luau-lsp/globalTypes.PluginSecurity.d.luau"
    )
    $Defs = $candidatos | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

$lsp = Get-ChildItem "$env:USERPROFILE/.vscode/extensions" -Filter "johnnymorganz.luau-lsp-*" -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $lsp) {
    Write-Error "luau-lsp nao encontrado. Instale a extensao johnnymorganz.luau-lsp no VS Code."
    exit 1
}
$motor = Join-Path $lsp.FullName "bin/server.exe"

# --- sourcemap --------------------------------------------------------------
# Regerado toda rodada: sourcemap velho aponta para arquivo que mudou de lugar,
# e o sintoma e "Unknown require" em codigo que esta certo.
# O rogen GERA o default.project.json a partir da estrutura de pastas. Sem
# rodar ele antes, o sourcemap sai de um project file velho e o sintoma e
# "Unknown require" em codigo que esta certo.
& rogen build 2>&1 | Out-Null

$mapa = "sourcemap.json"
& rojo sourcemap default.project.json -o $mapa 2>&1 | Out-Null
if (-not (Test-Path -LiteralPath $mapa)) {
    Write-Error "rojo nao gerou o sourcemap. Instale com: rokit add rojo-rbx/rojo"
    exit 1
}

Write-Host "motor: luau-lsp + sourcemap do Rojo + definitions do Roblox" -ForegroundColor DarkGray

# --- analisa ----------------------------------------------------------------
$arquivos = Get-ChildItem -Path $Src -Recurse -Filter *.luau |
    Where-Object { $_.FullName -like $Filter }

$args = @("analyze", "--sourcemap=$mapa", "--flag:LuauSolverV2=true")
if ($Defs) { $args += "--definitions=$Defs" }
$args += $arquivos.FullName

# O luau-lsp escreve [INFO] no stderr. Com ErrorActionPreference = Stop, o
# PowerShell transforma isso em erro e a analise morre antes de reportar.
$anterior = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$saida = & $motor @args 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch '\[INFO\]' }
$ErrorActionPreference = $anterior

# O mesmo arquivo e reanalisado uma vez por require que chega nele, entao
# um erro unico aparece repetido. Sem dedup a contagem mente.
$erros = @($saida | Select-String 'TypeError|SyntaxError' | ForEach-Object { $_.Line } | Select-Object -Unique)
$ciclos = @($saida | Select-String 'Cyclic module dependency')

if ($Detail -and $erros.Count -gt 0) {
    $erros | ForEach-Object { Write-Host "  $_" }
}
if ($ciclos.Count -gt 0) {
    Write-Host "$($ciclos.Count) require ciclico(s)." -ForegroundColor Red
    Write-Host "Lembre: ciclo degrada os genericos exportados, entao a tipagem colapsa junto." -ForegroundColor Red
}

Write-Host "total: $($erros.Count) erro(s), $($ciclos.Count) ciclo(s)"
