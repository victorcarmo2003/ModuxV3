# Benchmarks

Every number quoted in the documentation comes from here, and all of them are
measured — none are estimated. The harness lives in
[`tools/bench/`](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench)
and runs the real `luau-lsp`, not a cost model.

This page exists because a number with three significant figures invites the
question "measured how?". The answer is all here, including the part where the
current design **loses**.

## How to read the tables

**Baseline.** Loading the Roblox definitions costs between 1.5 and 2 seconds,
every time, whatever is being analyzed. The `net` column is the total minus that
constant. Without subtracting it, every style looks tied and the measurement
says nothing.

**Median, not mean.** Each `analyze` is a fresh process, and the first of a
sequence pays for a cold disk cache. The mean drags along with that outlier; the
median doesn't. The number of runs is written on every table.

**Equal load.** Where two typing variants are compared against each other, the
projects are synthetic and get the **same** shared surface, the same module
count, the same methods and the same cross-module traversals. All that changes
is how the type reaches the person writing. Comparing two real projects would
measure the difference in content, not in strategy.

**Declaration sites.** This is the variable that matters most and the easiest to
get wrong. A project with N modules has N places where `self` is built, not one.
A measurement with a single site measures the wrong cost by a factor of N.

### Environment

| | |
|---|---|
| CPU | Intel Xeon E5-2667 v4 @ 3.20 GHz |
| RAM | 12 GB |
| OS | Windows 11, build 26200 |
| analyzer | `luau-lsp` 1.69.0, with `--flag:LuauSolverV2=true` |
| definitions | `globalTypes.PluginSecurity.d.luau` from the VS Code extension |
| Python | 3.12.10 |
| date | 2026-09-20 |

## Why `analyze` takes so long

Measured on the [template](https://github.com/victorcarmo2003/ModuxTemplate),
a real project: 11 modules, 61 `.luau` files. Median of 3 runs, wall clock of
the whole process.

| what was analyzed | files | time |
|---|---:|---:|
| an empty file | 1 | 1,601 ms |
| one type leaf | 1 | 3,331 ms |
| one module | 1 | 3,439 ms |
| the leaves only | 21 | 3,474 ms |
| the modules only | 22 | 5,443 ms |
| **the whole project** | **61** | **5,599 ms** |

Those 5.6 s split into four pieces, and none of them is the one you'd expect:

| piece | cost | what it is |
|---|---:|---|
| Roblox definitions | 1,601 ms | 29% — nothing to do with Modux |
| the first file | ~1,800 ms | 32% — building the framework's type graph, once |
| the other 21 modules | ~2,000 ms | 36% — ~95 ms each |
| everything else | ~160 ms | 3% — 39 files, ~4 ms each |

**Almost a third isn't Modux.** Loading
`globalTypes.PluginSecurity.d.luau` costs 1.6 s on an empty file, and the same
1.6 s on a 200-module project. It's a constant of the Roblox toolchain, and it
would show up the same on any Luau project. Every table on this page that says "net" has
that constant subtracted; without subtracting it, everything looks tied.

**Another third is paid once.** Going from an empty file to *any one* file of
the project costs ~1.8 s. That's the analyzer resolving the Manifest, the
leaves it requires and the framework chain. The second module doesn't pay it
again.

**The leaves are nearly free.** Twenty leaves beyond the first cost 143 ms
together, ~7 ms each. That's the most direct evidence that the cost of Modux's
typing is **not** in the file the generator writes — it's in whoever consumes
it.

### The editor never analyzes the whole project

This is the part of the page most often read wrong, so plainly: **the full
`analyze` is not something you wait for.** It's the CI number. The editor never
does it.

`luau-lsp` checks **the file you're editing**, and that's it. It doesn't sweep
the 21 leaves or the other 21 modules because you opened a file — there is no
sweep.

But the file you opened requires the Manifest, and the Manifest requires every
leaf on its side. So the cost arrives from the inside, and that's why the table
above holds the most important line on this page:

| | time |
|---|---:|
| one module, alone | 3,439 ms |
| the whole project, 61 files | 5,599 ms |

**Opening one file already costs 61% of the whole project.** Not because the
editor analyzed the rest, but because that one file pulls the entire type
chain.

That sounds bad and is the best news on the page, for one reason: **it's paid
once.** The server starts, resolves that chain, and keeps it in memory. Every
edit after that reuses it — which is why completion answers in under 1 ms (see
below) on a project whose full `analyze` takes seconds.

What you actually feel:

- **Opening the project:** a few seconds until typing responds. Once.
- **While typing:** under 1 ms.
- **In CI:** the full `analyze`, and that's the only place the big numbers on
  this page show up.

::: tip In CI, analyze everything at once
One file per process would pay the 1.6 s of definitions **61 times** — over
97 s of baseline alone, before any useful work. In one batch you pay it once.
Splitting analysis across jobs multiplies the constant per job.
:::

### Where it becomes a problem

Those ~95 ms per module aren't constant: they depend on **how many entries the
Manifest has**. Measured on two synthetic trees, analyzing the modules only and
subtracting the baseline:

| Manifest | cost per module | total |
|---|---:|---:|
| 100 entries | 223 ms | 22.3 s |
| 150 entries | 533 ms | 80.0 s |

N grew 1.5× and the cost **per module** grew 2.4×. That's the whole mechanism:
each `Modux.Controller("X")` resolves the Manifest of its side; bigger
Manifest, more expensive site; and there are N sites. **N × cost(N)**, with the
cost already growing faster than linear — which is why the curve lands near N³,
not N².

On that same tree of 150, the accumulation per file is clean:

| files analyzed | time | `too complex` |
|---:|---:|---:|
| 1 | 3,160 ms | 0 |
| 10 | 7,197 ms | 1 |
| 50 | 29,604 ms | 10 |
| 150 | 81,706 ms | 26 |

Linear in the number of files, at ~0.53 s each. There is no pathological file:
it's 150 files costing half a second each.

::: warning Those 81 s are already with the solver giving up
26 of the 150 files ended in `Code is too complex to typecheck`. The solver hit
its internal limit and stopped. Going all the way would cost more.
:::

### Autocomplete

Warm median of `textDocument/completion`, 7 calls, first one discarded:

| N | V3 |
|---:|---:|
| 10 | 0.5 ms |
| 25 | 0.5 ms |
| 50 | 0.7 ms |
| 100 | 0.9 ms |

Far below what's perceptible while typing, and it doesn't grow with N in any
relevant way. **V3's wall is the batch `analyze`, not typing.** What feels the
seconds is CI, not whoever is writing.

## Where the cost lives

If the problem is N sites × an N-entry Manifest, the obvious question is whether
reorganizing the types can dodge it. Five alternatives were built and measured.
All at N=100 with N declaration sites, median of 3 runs.

| variant | what changes | net | errors |
|---|---|---:|---:|
| **`v3sites`** | **the current design** | **18,248 ms** | 0 |
| `v3nobuild` | no `SelfOf.Build`, no `Pick` — just `index<AllControllers, ID>` | 16,784 ms | 0 |
| `v3nopick` | no `Pick.Table`, literal `Dependencies` | 17,058 ms | 0 |
| `v3deps` | literal `Dependencies` per leaf | 17,526 ms | 0 |
| `v3leaf` | `Build` inside each leaf | 16,754 ms | 2 |
| `v3pre` | `Build` precomputed in the Manifest | 227 ms | **209** |

And for scale, measured in the **same** run:

| reference | net |
|---|---:|
| plain Luau, flat | 106 ms |

::: warning Below ~500 ms, don't trust the decimal
The two tables above come from different runs, each with its own baseline. The
same cheap variant can show up as 69 ms in one and 319 ms in the other — not
because it changed, but because subtracting a 1.8 s constant from a 1.9 s
total leaves a remainder with an enormous relative error.

Comparing small numbers **across** tables is meaningless; comparing within one
table is fine. And this section's conclusion doesn't rest on it: 16.8 s against
18.2 s is a gap large enough to survive the noise, and the gap between 18 s and
0.5 s is not subtle.
:::

**The type function machinery is not the cost.** `v3nobuild` has neither `Build`
nor `Pick` — no type function on the path — and still costs 16.8 s, 92% of the
full design. Dropping `Pick` saves 6%. Dropping `Build` as well saves 8%. The
rest, the other 92%, is the Manifest traversal, which none of the variants
eliminates because it is inherent to `Modux.Controller("Name")` resolving a name
into a type: that needs a central table, and every module needs it.

**The most obvious fix is the one that breaks.** `v3pre` precomputes each
module's `self` inside the Manifest — the generator knows every module's
`Require` list, so it could write everything resolved and the declaration would
become a plain index. It shows up at 227 ms in the table, and that is an
illusion: those are **209 analysis errors**, one of them
`Code is too complex to typecheck`. It isn't fast, it gives up. At N=50, where it
still compiled, it measured 3,200–3,500 ms — 60% **worse** than the current
design.

The trap is always the same: moving a type function instantiation into a file
that many others require makes each requirer resolve all N instead of just its
own.

## The per-side ceiling

Measured with [`tools/bench/bench_types.py`](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench),
which generates **real** controllers and services inside `src/`, runs `modux` to
produce the Manifest and the leaves, and analyzes the whole project. Six methods
and four dependencies per module. Measured on 2026-09-18.

| configuration | files | `analyze` | errors |
|---|---:|---:|---:|
| 75 controllers | 227 | 12.1 s | 0 |
| 100 controllers | 287 | 25.3 s | 0 |
| **50 controllers + 50 services** | 267 | **9.1 s** | 0 |
| 150 controllers | 407 | 83.5 s | 33 × `too complex` |

**The budget is per side.** A hundred modules on one side alone cost 25.3 s; the
same hundred split between client and server cost 9.1 s. Nearly 3× cheaper,
because `AllControllers` and `AllServices` are separate types and the cost is
superlinear in **each** side's N, not in the total.

**The wall sits between 100 and 150 per side**, with
`Code is too complex to typecheck`.

::: tip Redone on modux 0.7.0: the wall didn't move
0.7.0 took the type leaf out from beside the module and moved it to
`src/ModuxTypes/<side>/<Id>.luau`. The obvious question is whether that touched the
cost. It didn't — measured A/B on the same machine in the same session, N=100
controllers:

| modux | `analyze` | errors |
|---|---:|---:|
| 0.6.11 | 33,742 ms | 0 |
| 0.7.0 | 33,260 ms | 0 |

Difference inside the noise. And the wall stays put: at N=150, 0.7.0 gives
111,626 ms and 27 `too complex`, against 0 errors at N=100.

This run came out ~34% above the table above (33.3 s against 25.3 s at N=100),
and that's machine state, not a regression — the same factor shows up on both
rows, and the A/B against 0.6.11 at that same moment settles it. That's why
the table above wasn't rewritten: its numbers come from a rested machine, and
comparing across runs is exactly what this page warns against.

What the migration did touch was **generation**, and for the worse before it
got better: 622 ms on 0.6.11 against 1,186 ms on 0.7.0. The cause was a sweep
redoing `canonicalize` on every target once per file, hidden until then because
half the files left through a shortcut that the centralized leaf removed.
Fixed, the same measurement gives **531 ms** — faster than before the layout
change.
:::

The synthetic harness lands in the same place by another route: at N=150, with
generated modules and none of the real project's quirks, `v3sites` takes 80.4 s
and reports 26 `too complex` errors. Two independent measurements, same wall.

Past it things only get worse: at N=200 it is 151 s and 105 errors. This is not
a step you cross with patience — the solver stops answering and the project stops
having trustworthy types.

**It isn't module count, it's inference work.** Six dense files full of nested
closures brought down an N=100 that passed clean without them. A few heavy files
cost more than dozens of simple modules. The callback form
(`X:OnInit(function(self) ... end)`) costs only 7% more than a declared method —
it is not the villain.

**Real-world reference.** Of the 27 games on disk used as a sample, the largest
has 46 service and controller modules across both sides, i.e. ~23 per side. Four
to five times the headroom.

## Runtime

::: warning These numbers have no script in this repository
They were measured inside Studio, with benchmark modules that were never
committed. They're here because they were measured, but they are **not
reproducible from this repository** the way the ones above are. Treat them with
more reserve than the rest of the page.
:::

| | |
|---|---|
| framework overhead per component, per frame | 0.21 µs |
| 1,000 components with `OnTick` every frame | 1.3% of the 60 fps budget |
| going through `self.Dependencies.X` on a call | +8.8 ns, ~0 if hoisted to a local |
| Modux's own work at boot | 0.36 ms (the modules' `require` is ~88%) |

Type function is an **analysis** cost and is worth zero at runtime — both
frameworks do `setmetatable` plus a lookup, and nothing in the typing survives
the compiler.

## Reproducing

```sh
python tools/bench/bench_estilos.py 10 25 50 100
```

```sh
BENCH_REPS=5 BENCH_ESTILOS=v3sites python tools/bench/bench_estilos.py 200
```

Requirements and what each environment variable does are in the
[harness README](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench).

## What was not measured

- **Studio.** Everything here runs on the command-line `luau-lsp`. The editor has
  its own cache and its own scheduling, and it is the final verdict.
- **Memory.** Neither analysis nor runtime.
- **N above 200.** The wall already shows up at N=150, so measuring beyond it
  would say little: the solver stops responding and the project loses reliable
  typing well before that.
- **Other frameworks.** This page measures Modux V3 against itself — the cost
  of each piece of the typing and what happens as the project grows. Comparing
  against another framework would mean matching not just the load but how much
  each one sets out to verify, and that's a different measurement.
