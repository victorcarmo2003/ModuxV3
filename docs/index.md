---
layout: home

hero:
  name: Modux
  text: Auto-Typed
  tagline: Framework com tipagem automática para Roblox que potencializa os seus types e te incentiva a manter sempre boas práticas.
  actions:
    - theme: brand
      text: Guia
      link: /guia/introducao
    - theme: alt
      text: Tipagem
      link: /tipagem/
    - theme: alt
      text: Setup
      link: /setup/

features:
  - title: Sem anotar nada
    details: Um gerador lê os seus módulos e escreve uma folha de tipo por módulo. O framework junta essas folhas com type functions do Luau. Você não declara a mesma superfície duas vezes.
  - title: Lado não atravessa
    details: Um Controller que declara Require de um Service interrompe a geração, com uma mensagem dizendo quem está de que lado. Comunicação entre lados é rede, e rede é explícita.
  - title: Custo medido, não estimado
    details: 0,21 µs por componente por frame. 1,3% do orçamento de 60 fps com mil componentes. O que pesa é o corpo que você escreve, não o framework.
---
