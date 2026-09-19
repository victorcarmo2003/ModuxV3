---
layout: home

hero:
  name: Modux
  text: Auto-Typed
  tagline: An auto-typing framework for Roblox that gets the most out of your types and nudges you toward good practice.
  actions:
    - theme: brand
      text: Guide
      link: /en/guia/introducao
    - theme: alt
      text: Typing
      link: /en/tipagem/
    - theme: alt
      text: Setup
      link: /en/setup/

features:
  - title: Nothing to annotate
    details: A generator reads your modules and writes one type leaf per module. The framework stitches those leaves together with Luau type functions. You never declare the same surface twice.
  - title: Sides don't cross
    details: A Controller that declares a Require on a Service halts generation, with a message saying who is on which side. Talking across sides is networking, and networking is explicit.
  - title: Measured, not estimated
    details: 0.21 µs per component per frame. 1.3% of the 60 fps budget with a thousand components. What costs you is the body you write, not the framework.
---
