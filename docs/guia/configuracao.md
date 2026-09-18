# Configuração

```lua
Modux.Start({ DebugLevel = "High", Profiling = true })
```

Ou separado, quando o bootstrap precisa configurar antes:

```lua
Modux.Configure({ DebugLevel = "Medium" })
Modux.Start()
```

Passar settings nos dois lugares é erro: `settings came from both Configure and
Start; use one of them`.

## Settings

```lua
type Settings = {
	Profiling: boolean?,
	DebugLevel: ("None" | "Low" | "Medium" | "High")?,
}
```

### DebugLevel

| valor | mostra | avisa lento acima de |
|---|---|---|
| `None` | nada | — |
| `Low` | tempo total de boot | 100 ms |
| `Medium` | + singletons e módulos requeridos | 16,7 ms |
| `High` | + tempo de cada `require` | 1 ms |

O aviso de lento vale para cada callback de `OnInit` e `OnStart`, com o nome do
módulo:

```
[Modux] OnStart of "DataService" took 42.1 ms
```

### Profiling

Marca as fases no MicroProfiler **e** categoriza a memória por módulo, então a
aba de memória do Studio mostra quem alocou o quê.

```lua
Modux.Start({ Profiling = true })
```

## Modux.Stop()

Desliga o clock, limpa os ticks e derruba os componentes. Útil em teste; num
jogo em produção normalmente não é chamado.

::: warning
`Stop` não desfaz o que os teus módulos fizeram. Service e Controller não têm
`OnDestroy`, então recurso de escopo global criado por eles continua vivo.
:::

## Bootstrap

O bootstrap é um `Script` por lado, e é teu:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

Modux.Start({ DebugLevel = "Medium", Profiling = false })
```
