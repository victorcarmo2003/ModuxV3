# Ciclo de vida

`OnInit` → `OnStart` → `OnTick` → `OnDestroy` (só componente).

A injeção acontece **antes** de qualquer `OnInit`, o que faz dependência mútua
A↔B funcionar: quando o teu código roda, tudo já existe.

O loader completa **todos** os `OnInit` antes de começar qualquer `OnStart`, e
ordena as duas fases por `Priority` decrescente. Isso é o que permite dizer
"registre no `OnInit`, dispare no `OnStart`" e ter certeza da ordem.

## OnInit()

```lua
function M:OnInit(callback: (self) -> ())
```

Setup do próprio módulo. Registrar handler, criar signal, montar estado.

## OnStart()

```lua
function M:OnStart(callback: (self) -> ())
```

Roda quando todos os `OnInit` terminaram. É onde você pode contar que o resto
do jogo existe.

::: tip Padrão útil
Um módulo com `Priority` alta roda o **primeiro** `OnStart` — depois de todo
`OnInit`, antes de qualquer outro `OnStart`. É a janela certa para travar
configuração, como o `start()` de uma lib de rede.
:::

## OnTick()

```lua
function M:OnTick(callback: (self, deltaTime: number) -> (), tickRate: number?, priority: number?)
```

Sem os dois últimos: **1 Hz, priority 1**.

`priority` maior roda primeiro, e o empate desempata pela ordem de registro —
determinístico, não muda quando outro módulo entra.

O `priority` do tick é independente do `Priority` do módulo. Um módulo pode
querer o primeiro `OnStart` e o **último** tick do frame:

```lua
const Net = Modux.Service("Net", { Priority = 1000 })

Net:OnTick(function(self)
	self:Flush()
end, 60, -1000)
```

## OnDestroy()

```lua
function M:OnDestroy(callback: (self) -> ())
```

**Só existe em Component.** Service e Controller são singletons e não têm essa
fase, o que significa que um recurso de escopo global — um `effect` reativo, por
exemplo — não tem onde ser solto.

## Varredura de estado pré-existente

Jogadores que já estão no servidor quando o jogo sobe devem ser varridos no
`OnStart`, não no `OnInit`:

```lua
PlayerService:OnInit(function(self)
	Players.PlayerAdded:Connect(function(p) self:Watch(p) end)
end)

PlayerService:OnStart(function(self)
	for _, p in Players:GetPlayers() do
		self:Watch(p)
	end
end)
```

Varrendo no `OnInit`, os módulos de prioridade menor ainda não conectaram os
handlers deles e perderiam quem já estava lá.
