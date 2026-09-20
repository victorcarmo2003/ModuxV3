# Componentes
Componentes são unilaterais para server e para client.

O Componente é ligado a uma `Instance` via CollectionService, e existe um por
instância tagueada. Sem `Tag` declarada, a tag é o próprio ID.

```lua
const Highlight = Modux.Component("Highlight", { Require = { "Render" } })

function Highlight:TurnOn()
	self.Instance.Color = Color3.new(1, 1, 0)
end

Highlight:OnDestroy(function(self)
	self.Instance.Color = Color3.new(1, 1, 1)   -- solta o que TurnOn tomou
end)

return Highlight
```

`self.Instance` sempre existe e sempre é a instância para a qual o objeto foi
construído.

## Acesso de fora

Qualquer módulo alcança componentes por `self.Components`, tipado por ID:

```lua
self.Components.Highlight:Get(part)       -- o objeto, ou nil
self.Components.Highlight:Create(part)    -- constrói e devolve na hora
self.Components.Highlight:All()           -- todos os vivos
self.Components.Highlight:Destroy(part)   -- derruba e tira a tag
```

`Create` constrói e devolve **na mesma linha**, porque `AddTag` só avisa no
próximo frame e esperar isso é gambiarra. Ele também é seguro contra duplicata:
se o objeto já existe para aquela instância, devolve o existente.

De dentro do próprio componente, `self:Destroy()` faz o mesmo que
`self.Components.X:Destroy(self.Instance)`.

## Quando os componentes sobem

Componente tagueado pelo Studio sobe **depois** que todos os singletons
startaram. `Create` chamado de um `OnInit` também funciona: os templates já
receberam `Dependencies`, `Libs` e `Components` antes do loader rodar.

## Ciclo de vida

Componente é a única espécie com `OnDestroy`. Ele dispara quando a tag sai, ou
quando alguém chama `Destroy`.

Criar e destruir no mesmo frame é seguro: o manager confere o estado atual da
tag antes de construir ou derrubar, então o sinal pendente do CollectionService
não ressuscita um objeto já morto.

## Rede, em componente

Componente **não** deve registrar responder de rede. Ele sobe depois do start
da lib de rede, e um responder costuma ser único por definição, um por
instância seria errado de qualquer forma. É apenas convenção.