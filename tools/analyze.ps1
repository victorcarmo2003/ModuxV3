<#
.SYNOPSIS
    Varre o projeto com o luau-analyze upstream, fora do Roblox Studio.

.DESCRIPTION
    O luau-analyze nao conhece `game:GetService` nem `require(ReplicatedStorage...)`,
    entao este script monta um espelho plano dos modules (um arquivo por module,
    nome unico), apaga as linhas de GetService e troca os require por caminho
    relativo. Depois roda a analise em cada arquivo do espelho.

    Saida vazia num arquivo = passou. Mas arquivo limpo NAO prova nada: quebre
    de proposito e confirme que acusa, senao voce tem silencio em vez de tipagem.

.PARAMETER Src
    Pasta do codigo. Padrao: src

.PARAMETER Out
    Pasta do espelho. Padrao: .luau-mirror (ignorada pelo git)

.PARAMETER Luau
    Caminho do luau-analyze.exe. Padrao: .\luau-analyze.exe

.PARAMETER Detail
    Mostra as mensagens de erro em vez so da contagem.

.PARAMETER Filter
    Analisa so os arquivos cujo nome bate com esse curinga. Ex: -Filter Manifest*

.EXAMPLE
    .\tools\analyze.ps1

.EXAMPLE
    .\tools\analyze.ps1 -Filter Controller.luau -Detail

.NOTES
    Instalar o binario (uma vez, na raiz do repo):

        Invoke-WebRequest -Uri "https://github.com/luau-lang/luau/releases/download/0.716/luau-windows.zip" -OutFile luau.zip
        Expand-Archive -Path luau.zip -DestinationPath . -Force
        Remove-Item luau.zip

    Precisa ser 0.712 ou mais novo: antes disso o `const` aparece como erro de
    sintaxe. E sem --fflags=LuauSolverV2=true as type functions nao rodam.
#>
param(
    [string]$Src    = "src",
    [string]$Out    = ".luau-mirror",
    [string]$Luau   = ".\luau-analyze.exe",
    [string]$Filter = "*",
    [switch]$Detail
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Luau)) {
    Write-Error "luau-analyze nao encontrado em '$Luau'. Veja as notas no topo deste script."
    exit 1
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null

# --- monta o espelho -------------------------------------------------------
# Espelho plano. Nome unico e obrigatorio: o projeto tem tres `Type.luau`
# (Zombie, Skeleton, Default) e, achatados, um sobrescreve o outro — o sintoma
# e "Cannot add property X" num modulo que esta certo, porque ele recebeu a
# folha do vizinho. Quando o nome base colide, o do pai entra na frente:
# Zombie/Type.luau -> ZombieType.luau.
Remove-Item -Recurse -Force -LiteralPath $Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$arquivos = Get-ChildItem -Path $Src -Recurse -Filter *.luau

# nome base, do jeito que o Rojo resolve
function Get-Base($f) {
    if ($f.Name -eq "init.luau") { $f.Directory.Name } else { [IO.Path]::GetFileNameWithoutExtension($f.Name) }
}

$contagem = @{}
foreach ($f in $arquivos) {
    $b = Get-Base $f
    $contagem[$b] = 1 + ($contagem[$b] ?? 0)
}
# nomes que precisam de desempate
$colide = @($contagem.Keys | Where-Object { $contagem[$_] -gt 1 })

function Get-Unico($f) {
    $b = Get-Base $f
    if ($colide -contains $b) { "$($f.Directory.Name)$b" } else { $b }
}

foreach ($f in $arquivos) {
    $destino = Join-Path $Out "$(Get-Unico $f).luau"
    $pasta   = $f.Directory.Name

    (Get-Content -LiteralPath $f.FullName) |
        ForEach-Object {
            # Servico vira stub `any` em vez de sumir: assim as linhas que
            # derivam dele (StarterPlayer.StarterPlayerScripts.client) ainda
            # resolvem, so que sem tipo.
            $l = $_ -creplace 'game:GetService\([^)]*\)', '(nil :: any)'

            # `-creplace` e case-SENSITIVE de proposito. Com o `-replace`
            # normal, `normalizeRequire(value: any)` casa com `Require(...)` e
            # vira `normalizerequire("./any")` — erro de sintaxe num arquivo
            # que esta certo.
            [regex]::Replace($l, 'require\(([^)]*)\)', {
                param($m)
                $partes = $m.Groups[1].Value -split '\.' |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*$' }
                if ($partes.Count -eq 0) { return $m.Value }

                $ultimo = $partes[-1]
                if ($colide -contains $ultimo) {
                    # desempata pelo dono: `script.Type` e do proprio arquivo,
                    # `....Entity.Zombie.Type` traz o dono no penultimo.
                    $dono = if ($partes.Count -ge 2 -and $partes[-2] -ne 'script') { $partes[-2] } else { $pasta }
                    "require(`"./$dono$ultimo`")"
                } else {
                    "require(`"./$ultimo`")"
                }
            }, [Text.RegularExpressions.RegexOptions]::None)
        } |
        Set-Content -LiteralPath $destino -Encoding utf8
}

# --- analisa ---------------------------------------------------------------
$totalErros  = 0
$totalCiclos = 0

$linhas = Get-ChildItem -Path $Out -Filter *.luau |
    Where-Object { $_.Name -like $Filter } |
    ForEach-Object {
        $saida  = & $Luau --mode=strict --fflags=LuauSolverV2=true $_.FullName 2>&1
        $ciclos = @($saida | Select-String 'Cyclic module dependency').Count
        $erros  = @($saida | Select-String 'TypeError|SyntaxError').Count

        $script:totalErros  += $erros
        $script:totalCiclos += $ciclos

        if ($Detail -and ($erros -gt 0 -or $ciclos -gt 0)) {
            Write-Host "--- $($_.Name) ---" -ForegroundColor Yellow
            $saida | Select-String 'TypeError|SyntaxError' | Select-Object -First 10 | ForEach-Object {
                Write-Host "  $_"
            }
        }

        [PSCustomObject]@{ Arquivo = $_.Name; Ciclos = $ciclos; Erros = $erros }
    }

$linhas | Format-Table -AutoSize

if ($totalCiclos -gt 0) {
    Write-Host "$totalCiclos require ciclico(s). Rode com -Detail para ver a cadeia." -ForegroundColor Red
    Write-Host "Lembre: ciclo tambem degrada os genericos exportados, entao a tipagem colapsa junto." -ForegroundColor Red
}
Write-Host "total: $totalErros erro(s), $totalCiclos ciclo(s)"
