# Modux
Abaixo, explico sobre como funciona a estrutura do gerador de arquivos, preenchimento e também alguns comandos que podem ser utilizados.

## Watcher:
O watcher lê o conteúdo de cada module e a partir deles, gera toda a estrutura de funções, parâmetros e alguns self values simples e então escreve as folhas de tipo nesta estrutura:
<FileTree title="Estrutura gerada" :paths="[
  'client/Controller/init.luau ',
  'client/Controller/Type.luau #(auto-gerada)',
]" />

E também preenche o Manifest, no client-side por exemplo:
```luau
local StarterScripts = game:GetService("StarterPlayer").StarterPlayerScripts
local Example = require(StarterScripts.client.Example.Controller.Type)

export type AllControllers = {
	Example: Example.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
```

O parser, responsável por identificar e tipar conforme os valores, é embutido: não há nada para instalar ao lado do binário.

## Comandos

### > modux generate

Parseia por todos os modules, controllers e services registrados e gera o type dele:
```sh
modux generate
#OUTPUT:
[modux] leaf: src/Player/server/PlayerService/Type.luau
[modux] manifest server: src/Modux/server/Manifest/init.luau (6 modules)
[modux] modules server: src/Modux/server/Modules.luau
[modux] libs: src/Modux/shared/Libs.luau
[modux] 118 ms
```

Arquivo que já está correto não é reescrito, então rodar de novo imprime:
```sh
[modux] up to date.
```

### > modux watch

Regenera a cada mudança até você interromper. É o que compõe a tarefa `dev` do template, executada pelo VS Code, e é o que
você normalmente vai usar.

```sh
modux watch
```

::: danger Watcher com versão velha:
O processo carrega o binário na hora que sobe. Depois de um `rokit update`, um
watcher que continua rodando ainda usa a versão antiga e vai **reescrever** os
arquivos gerados com o comportamento antigo — em silêncio, por cima do que você
acabou de gerar. Reinicie o watcher depois de atualizar!
:::

### > modux check
Serve como uma verificação de integridade. Falha se qualquer coisa no disco difere do que o `generate` escreveria. É o
comando para o CI.

```sh
modux check
#OUTPUT:
stale: src/Player/server/PlayerService/Type.luau
modux: 1 file(s) out of date. Run `modux generate`.
```
### > modux list

Lista os módulos encontrados:

```sh
modux list
#[Module]      [Tipo]     [Dependência]:
NetService     Service    src/Net/server/NetService/init.luau  deps: -
ProfileService Service    src/Profile/server/ProfileService/init.luau  deps: PlayerService, NetService
Vital          Component  src/Vital/server/Vital/init.luau  deps: VitalService
```

### > modux extract

Despeja a forma extraída de um módulo como JSON. Serve para entender por que o
gerador leu algo diferente do que você esperava.

Por exemplo, esse é um controller de Round, para acompanhar pelo client-side e criar um source com o Vide
```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Status = "Waiting" | "Playing" | "Ending"

const RoundController = Modux.Controller("RoundController", { Priority = 800 })

function RoundController:Setup()
	self.Status = Vide.source("Waiting") :: Vide.Source<Status>
	self.Seconds = Vide.source(0) :: Vide.Source<number>
end

RoundController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Round:onClient(function(payload)
		self.Status(payload.Status)
		self.Seconds(payload.Seconds)
	end)
end)

return RoundController
```
Executando o extract:
```sh
modux extract src/Round/client/RoundController/init.luau
#OUTPUT:
{
  "id": "RoundController",
  "kind": "Controller",
  "file": "C:/Users/hakor/Documents/GitHub/ModuxTemplate/src/Round/client/RoundController/init.luau",
  "services": [
    {
      "alias": "ReplicatedStorage",
      "service": "ReplicatedStorage"
    },
    {
      "alias": "StarterPlayer",
      "service": "StarterPlayer"
    }
  ],
  "requires": [
    {
      "alias": "Vide",
      "expr": "ReplicatedStorage.Packages.Vide"
    },
    {
      "alias": "Modux",
      "expr": "StarterPlayer.StarterPlayerScripts.client.Modux"
    }
  ],
  "local_types": [
    {
      "name": "Status",
      "text": "export type Status = \"Waiting\" | \"Playing\" | \"Ending\""
    }
  ],
  "methods": [
    {
      "name": "Setup",
      "signature": "(self: Public) -> ()"
    }
  ],
  "fields": [
    {
      "name": "Seconds",
      "ty": "Vide.Source<number>"
    },
    {
      "name": "Status",
      "ty": "Vide.Source<Status>"
    }
  ],
  "dependencies": [],
  "declared_require": [],
  "issues": []
}
```
