# Pick

`src/Modux/shared/Types/Pick.luau`

Recorta uma tabela grande — na prática o Manifest — pelas chaves pedidas. É o
que transforma `Require = { "A", "B" }` num `self.Dependencies` com exatamente
A e B.

## Table()

```lua
export type function Table(list: type, id: type): type
```

**Detalhes**

`id` aceita quatro formas:

| forma | resultado |
|---|---|
| singleton (`"A"`) | o **valor** daquela chave, não uma tabela |
| union (`"A" \| "B"`) | tabela com as duas |
| array de singletons (`{ "A", "B" }`) | tabela com as duas |
| `never` | `any` |

A diferença entre singleton solto e array de um elemento é intencional:
`Table<M, "A">` devolve o módulo A, `Table<M, { "A" }>` devolve
`{ A: <módulo A> }`.

Chave que não existe no Manifest é erro, com a lista do que existe:

```
[Manifest] "Invetory" does not exist. Available: Camera, Input, Inventory
```

**Exemplo**

```lua
type Manifest = {
	Currency: { Add: () -> (), Sub: () -> () },
	Data: { Fetch: () -> () },
	Player: { Respawn: () -> () },
}

type Um = Pick.Table<Manifest, "Currency">
-- { Add: () -> (), Sub: () -> () }

type Dois = Pick.Table<Manifest, "Player" | "Data">
-- { Player: {...}, Data: {...} }
```

## Quando as chaves alargam

Se o literal perder o tipo e virar `{string}`, a função recusa em vez de
devolver algo errado em silêncio:

```
[Manifest] WIDENED: as keys viraram `string`.
Use `:: { "A" | "B" }` no literal, ou passe a union direto
```

Acontece quando um array de strings é passado sem um tipo esperado que o
segure. O conserto é anotar o literal.

## Map()

```lua
export type function Map(list: type, id: type): type
```

Igual ao `Table`, mas sempre devolve tabela — singleton solto também vira
`{ Chave: valor }` — e `never` devolve `{}` em vez de `any`.

::: warning
`Map` não tem âncora no arquivo e não é usado pelo framework. Está lá como
material de leitura; se for usar, instancie no próprio arquivo primeiro, ou ele
não reduz no editor.
:::
