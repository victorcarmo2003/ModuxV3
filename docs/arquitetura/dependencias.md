# Dependências

Um módulo declara o que precisa em `Require`, e recebe em `self.Dependencies`
já tipado.

```lua
const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton", "Camera" } })

function Zombie:Attack()
	self.Dependencies.Skeleton:ShootArrow()
	self.Dependencies.Camera:Shake(2)
end
```

`self.Dependencies` contém **exatamente** o que foi declarado. Acessar um
módulo que existe mas não foi declarado é erro de análise:

```lua
self.Dependencies.Inventory:Add(item)
-- Key 'Inventory' not found in table '{ read Skeleton: ..., read Camera: ... }'
```

Isso sai de [`Pick.Table`](/tipagem/pick), que recorta o Manifest do lado pelas
chaves declaradas.

## Injeção antes do OnInit

Tudo é injetado antes de qualquer `OnInit` rodar, então dependência mútua
funciona:

```lua
const A = Modux.Controller("A", { Require = { "B" } })
const B = Modux.Controller("B", { Require = { "A" } })
```

O que **não** funciona é um usar o outro durante a carga do arquivo. No
`OnInit` em diante, os dois existem.

:::tip Informação
Se você eventualmente precisar que algum carregue antes do outro pois
algum dado precisa ser gerado ou algo do tipo, um dos parâmetros dos
props é a prioridade no load, maior -> primeiro, exemplo:
```lua
const A = Modux.Controller("A", { Require = { "B" }, Priority = 100 })
const B = Modux.Controller("B", { Require = { "A" }, Priority = 50 })
```
Nesse caso o A carrega primeiro. Mais detalhes em [Priority](#priority),
logo abaixo.
:::

## Lado não atravessa
Uma das coisas que permitiu esta versão escalar melhor foi dividir o Manifest
entre clientside e serverside, por isso que existe uma cópia em cada, e de bônus
Controllers não conseguem dar require em Service e Services não conseguem dar
require em Controllers pois um vive no server e o outro no client.

Um Controller que declara `Require` de um Service interrompe a geração do modux no cli:

```
[Manifest] src/Ui/client/Hud/init.luau is client and requires "DataService",
which is server.
  client cannot see server — move one of them, or go through the network.
```

Não é convenção nem lint: o gerador para. O lado sai do caminho da pasta, então
mover o arquivo para o server ou client e trocar para controller ou service, é o que resolve.

## Priority

`Priority` decide a ordem de `OnInit` e `OnStart` — maior roda primeiro. O
padrão é `1`.

Priority **não** é dependência. Declarar `Require` garante que o módulo existe e
está injetado; `Priority` só controla quem roda a fase antes. Use `Require` para
alcançar, `Priority` para ordenar.

```lua
const Net = Modux.Service("Net", { Priority = 1000 })     -- primeiro
const Player = Modux.Service("Player", { Priority = 900 })
const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })
```
