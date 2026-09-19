# Struct

`src/Shared/Types/Struct.luau`

Transformações sobre tabela. Nenhuma é usada pelo framework — são para o teu
código.

Todas devolvem `any` quando recebem `any`, `unknown` ou `never`, e erram com
mensagem se receberem algo que não é tabela.

```lua
type Example = {
	name: string,
	hp: number,
	weapon: string?,
}
```

## Partial()

Torna todo campo opcional.

```lua
type T = Struct.Partial<Example>
-- { name: string?, hp: number?, weapon: string? }
```

Útil para um patch: a função aceita qualquer subconjunto sem você escrever um
segundo tipo.

```lua
function Data:Update(player: Player, patch: Struct.Partial<Save>) end
```

## Required()

O inverso: tira o `?` de todo campo.

```lua
type T = Struct.Required<Example>
-- { name: string, hp: number, weapon: string }
```

## Readonly() / Mutable()

Marca todo campo como só-leitura, ou remove a marca.

```lua
type T = Struct.Readonly<Example>
-- { read name: string, read hp: number, read weapon: string? }
```

## Assign()

Junta duas tabelas, rasa. Em conflito, **b** ganha.

```lua
type T = Struct.Assign<Example, { hp: string }>
-- { name: string, hp: string, weapon: string? }
```

## Merge()

Junta duas tabelas **em profundidade**: campo que é tabela dos dois lados é
fundido em vez de substituído.

```lua
type A = { owner: { id: number }, hp: number }
type B = { owner: { tag: string } }

type T = Struct.Merge<A, B>
-- { owner: { id: number, tag: string }, hp: number }
```

Profundidade limitada a 8 níveis, para não correr risco de recursão infinita —
type function que não termina aborta a análise e o Studio passa a mostrar tudo
como `any`.

## Record()

Constrói uma tabela a partir de chaves e um tipo de valor.

```lua
type T = Struct.Record<"a" | "b", number>
-- { a: number, b: number }
```

## Rename()

Troca o nome de um campo, preservando o tipo. Campo que não existe é erro.

```lua
type T = Struct.Rename<Example, "hp", "health">
-- { name: string, health: number, weapon: string? }
```

## DeepPartial() / DeepReadonly()

Como `Partial` e `Readonly`, descendo em tabelas aninhadas.

```lua
type Nested = { owner: { id: number }, hp: number }

type T = Struct.DeepPartial<Nested>
-- { owner: { id: number? }?, hp: number? }
```
