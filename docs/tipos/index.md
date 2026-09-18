# Como a tipagem funciona

O Modux não infere nada em runtime. A tipagem inteira é montada em tempo de
análise, por três peças que se encaixam.

## As três peças

### 1. O gerador lê a AST

`modux generate` parseia cada módulo e escreve um `Type.luau` ao lado dele —
a **folha**. A folha exporta só a superfície pública:

```lua
-- src/Player/server/PlayerService/Type.luau  (gerado)
export type Public = {
	Players: { Player },
	Joined: SignalLib.Signal<Player>,
	Watch: (self: Public, player: Player) -> (),
}
```

Sem inferência: o gerador lê o que você escreveu. Literal vira o tipo do
literal, função vira a assinatura declarada, e o resto pede `::`.

### 2. O Manifest junta as folhas

Um Manifest por lado indexa todas as folhas daquele lado:

```lua
export type AllServices = {
	PlayerService: PlayerService.Public,
	DataService: DataService.Public,
}
```

A folha não conhece o Manifest, e o Manifest não conhece o core. É essa direção
única que evita ciclo de require.

### 3. Type functions montam o `self`

O tipo do `self` sai de [`SelfOf.Build`](/tipos/selfof), que combina a folha do
próprio módulo com o que o framework injeta:

```lua
export type ServiceSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllServices, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
	}
>
```

`index<AllServices, ID>` pega a folha pelo ID. [`Pick.Table`](/tipos/pick)
recorta o Manifest pelas chaves declaradas em `Require`. O resultado é um
`self` que sabe exatamente o que aquele módulo tem e alcança.

## A biblioteca de tipos

Duas pastas, com propósitos diferentes.

**`src/Modux/shared/Types/`** — o que o framework precisa para existir.

| | |
|---|---|
| [`SelfOf`](/tipos/selfof) | monta o `self` a partir da folha mais os extras |
| [`Pick`](/tipos/pick) | recorta o Manifest pelas chaves declaradas |

**`src/Shared/Types/`** — utilitários para você usar no seu código.

| | |
|---|---|
| [`Struct`](/tipos/struct) | `Partial`, `Required`, `Readonly`, `Mutable`, `Assign`, `Merge`, `Record`, `Rename`, `DeepPartial`, `DeepReadonly` |
| [`Union`](/tipos/union) | `Exclude`, `Extract`, `NonNullable`, `KeyList`, `ValueList`, `Entries` |
| [`Occlude`](/tipos/occlude) | `Keys` — remove campos por nome |

Nada em `src/Shared/Types/` é requerido pelo framework. Apagar não quebra nada
além de quem usava.

## As quatro regras duras

Type function é Luau rodando numa VM real durante a análise. O risco dominante
**não é erro, é silêncio** — a maioria dos bugs compila limpo e devolve um tipo
levemente errado que aparece três arquivos adiante.

### `LuauSolverV2` é obrigatório

Sem a flag, type function não existe. `SelfOf.Build` nunca reduz, `self` fica
sem tipo, e o autocomplete devolve **zero item** — sem erro e sem aviso.

### A type function precisa ser instanciada no próprio arquivo

O luau-lsp só avalia uma type function exportada se ela for usada ao menos uma
vez no arquivo que a define. Sem isso ela vira `*error-type*` **só no LSP** — a
análise em linha de comando passa, e o editor não completa nada.

Por isso todo arquivo de tipos daqui termina com âncoras:

```lua
type _anchorPartial = Partial<Example>
type _anchorRequired = Required<Example>
```

Elas não são teste nem exemplo. São o que faz a função existir.

### Type function aplicada a genérico livre não reduz

Esta é a que mais custa tempo, porque o sintoma cai longe da causa:

```
Cannot add property 'Metodo' to table 'setmetatable<Build<Public, {...}>, ...>'
```

`function X:Metodo()` deixa de compilar num arquivo que estava certo. O que
aconteceu é que `Build<...>` não reduziu, e o motivo está nos extras.

Medido:

| nos extras de `Build` | |
|---|---|
| função **genérica** como campo direto | **não reduz** |
| função não genérica | reduz |
| genérico **aninhado** dentro de alias referenciado | reduz |
| **type function aplicada a genérico livre** (`index<Instances, Name>`) | **não reduz** |

A regra não é "genérico quebra". É **aplicação de type function não resolvida**
alcançável a partir dos extras. É por isso que [nem toda lib pode entrar em
`self.Libs`](/guia/libs#limite).

### `types` só existe dentro do corpo

Não há `require`, nem acesso a variável do script. Helper tem que ser colado
dentro de cada função que usa — repetição ali é o correto, não preguiça.

Consequência prática: type functions **não se enxergam**. Uma não pode chamar a
outra.

Detalhes e o catálogo de falhas silenciosas estão em
[Escrevendo a sua](/tipos/escrevendo).
