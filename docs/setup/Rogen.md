# Rogen

Os comandos para execução são:"
```sh
rogen build     # gera uma única vez
rogen watch     # gera continuamente
```

Gera o `default.project.json` a partir da estrutura de pastas, com arquitetura
feature-based: 
<FileTree :paths="[
  'src/Feature/server/FeatureService/init.luau',
  'src/Feature/client/FeatureController/init.luau',
  'src/Feature/shared/FeatureSettings/init.luau',
]" /> 

Chega como:
<FileTree :paths="[
  'Game/ServerScriptService/server/FeatureService/init.luau',
  'Game/StarterPlayer/StarterPlayerScripts/client/FeatureController/init.luau',
  'Game/ReplicatedStorage/shared/FeatureSettings/init.luau',
]"/> 

A configuração fica em `.rogen.json`. Entradas escritas à mão em
`project.tree` são preservadas e mescladas com o que ele deriva — é assim que
`Packages` entra na árvore.

```json
{
	"source": ["src"],
	"luau": { "output": "default.project.json", "build": "src" },
	"globIgnorePaths": ["**/*.md"],
	"project": {
		"name": "MeuJogo",
		"tree": {
			"$className": "DataModel",
			"ReplicatedStorage": { "Packages": { "$path": "Packages" } }
		}
	}
}
```

`globIgnorePaths` evita que ele tente mapear `README.md` como objeto do
DataModel.

::: tip Dica
O modo watch já é incluido em tasks.json do template padrão
uso no vscode: 

`CTRL + SHIT + P` e `Tasks: Run Task` e por fim `dev`

Consulte a [documentação do rogen](https://rogen-playfully.vercel.app)
para mais informações.
:::