# Modux
Abaixo, explico sobre como funciona a estrutura do gerador de arquivos, preenchimento e também alguns comandos que podem ser utilizados.

## Watcher:
O watcher lê o conteúdo de cada module e a partir deles, gera toda a estrutura de funções, parâmetros e alguns self values simples e então escreve as folhas de tipo nesta estrutura:
<FileTree title="Estrutura gerada" :paths="[
  'src/Example/client/ExampleController.luau # seu',
  'src/ModuxTypes/client/ExampleController.luau #(auto-gerada)',
]" />

A folha não fica ao lado do módulo: ela vai para `src/ModuxTypes/<lado>/<Id>.luau`,
endereçada pelo ID. É por isso que o módulo pode ser um arquivo solto — até a
**0.6.11** a pasta era obrigatória só para dois módulos vizinhos não brigarem
pelo mesmo `Type.luau`.

E também preenche o Manifest, no client-side por exemplo:
```luau
local StarterScripts = game:GetService("StarterPlayer").StarterPlayerScripts
local Example = require(StarterScripts.client.Types.ExampleController)

export type AllControllers = {
	ExampleController: Example.Public,
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
[modux] leaf: src/ModuxTypes/server/PlayerService.luau
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
stale: src/ModuxTypes/server/PlayerService.luau
modux: 1 file(s) out of date. Run `modux generate`.
```
### > modux list

Lista os módulos encontrados:

```sh
modux list
#[Module]      [Tipo]     [Dependência]:
NetService     Service    src/Net/server/NetService.luau  deps: -
ProfileService Service    src/Profile/server/ProfileService/init.luau  deps: PlayerService, NetService
Vital          Component  src/Vital/server/Vital.luau  deps: VitalService
```

O `ProfileService` aparece como pasta ali de propósito: ele guarda um
`Template.luau` só dele. Módulo com irmão continua pasta, módulo sozinho é
arquivo, e as duas formas dão a mesma instância.

### > modux fix

Achata todo módulo que ainda vive sozinho dentro de uma pasta: `Foo/init.luau`
vira `Foo.luau`. É o comando de migração para quem vinha da **0.6.11**.

```sh
modux fix --dry-run    # lista o que mudaria, sem tocar em nada
modux fix
#OUTPUT:
[modux] src/Net/server/NetService/init.luau  ->  src/Net/server/NetService.luau
[modux] kept src/Profile/server/ProfileService/init.luau: ... still holds Template.luau — left as a folder on purpose
[modux] folha anterior a 0.7.0 removida: src/Profile/server/ProfileService/Type.luau
[modux] run `modux generate` to write the leaves in their new place,
[modux] then `rogen build` again so Types/ enters the project file
```

Pasta que guarda outro arquivo **não** é achatada — aquilo é coisa sua. E o
`Type.luau` antigo sai mesmo de quem manteve a pasta: ele viraria uma cópia
desatualizada do tipo que ninguém mais escreve.

::: warning Os dois passos depois do fix não são opcionais
O `rogen` deriva o project file da estrutura de pastas e só enxerga `src/ModuxTypes/`
depois que existe um `.luau` lá dentro. Então a primeira migração precisa de
`modux generate` (que escreve as folhas) e `rogen build` **de novo** (que as
mapeia). Quem clona o template não passa por isso, porque lá as folhas já vêm
versionadas.
:::

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
modux extract src/Round/client/RoundController.luau
#OUTPUT:
{
  "id": "RoundController",
  "kind": "Controller",
  "file": "C:/Users/hakor/Documents/GitHub/ModuxTemplate/src/Round/client/RoundController.luau",
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
