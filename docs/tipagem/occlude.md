# Occlude

`src/Shared/Types/Occlude.luau`

## Keys()

Remove campos de uma tabela pelo nome.

```lua
export type function Keys(t: type, k: type)
```

**Detalhes**

`k` aceita um singleton ou uma união de singletons. Campo que não existe é
ignorado em silêncio — diferente de [`Rename`](/tipagem/struct#rename), que erra.

**Exemplo**

```lua
type Example = { name: string, hp: number, mana: number }

type T = Occlude.Keys<Example, "mana">
-- { name: string, hp: number }

type U = Occlude.Keys<Example, "hp" | "mana">
-- { name: string }
```

## Para que serve

O caso que motivou: esconder da superfície pública de um módulo os campos que
são detalhe interno, sem manter um segundo tipo à mão.

```lua
type Publico = Occlude.Keys<typeof(Servico), "_cache" | "_conexoes">
```

::: tip
Se o critério for uma convenção de nome e não uma lista fixa — "tudo que
começa com `_`" — vale escrever uma type function própria que filtre por
prefixo. Ver [Escrevendo a sua](/tipagem/escrevendo).
:::
