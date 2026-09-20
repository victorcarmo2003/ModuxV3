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

**Equal load.** Comparing the real V2 project against the real V3 one would
compare two different games. The projects compared here are synthetic and get
the **same** shared surface, the same module count, the same methods and the
same cross-module traversals. All that changes is how the type reaches the
person writing.

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

## V2 against V3: how analysis cost scales

Four styles, all `--!strict`, all with N declaration sites except where marked.
Median of 3 runs.

| N | plain Luau | V2, 1 site | V2, N sites | V3, N sites |
|---:|---:|---:|---:|---:|
| 10 | 31 ms | 94 ms | 42 ms | **193 ms** |
| 25 | 67 ms | 110 ms | 299 ms | **537 ms** |
| 50 | 53 ms | 166 ms | 239 ms | **2,079 ms** |
| 100 | 172 ms | 319 ms | 542 ms | **19,546 ms** |
| 150 † | — | — | 2,859 ms | **80,384 ms** |
| 200 † | — | — | 4,005 ms | **151,146 ms** |

Zero errors in every cell up to N=100, across all four columns. Past that, only
V3 breaks:

| N | V3 errors | V2 errors |
|---:|---|---|
| 150 | 26, every one `Code is too complex to typecheck` | 0 |
| 200 | 105, every one `Code is too complex to typecheck` | 0 |

† single run, not a median — each of those cells takes one to three minutes.

**V2 is cheaper to analyze, by a lot.** At 100 modules V3 costs 36× what V2
costs with the same number of sites. And the curves differ: doubling N from 50
to 100 multiplies V2 by 2.3 and V3 by **9.4** — something close to N³.

The reason is structural and was already documented: every V3 declaration site
resolves its side's whole Manifest. With N modules and an N-entry Manifest, that
is N × N by construction. V2 doesn't have that problem because its type doesn't
come from the call — it comes from an alias the generator writes, and an alias
resolves once.

::: tip What V2 charges instead
In V2, `Modux.Controller(id)` is declared as `(id: string, mode: Mode?) -> any`.
The type **does not arrive through the call**. For `self` to be typed, the file
needs the annotation — which is exactly what the "V2, N sites" column measures:
every module does `local C: T.ModX = M.Controller("ModX")`.

The "V2, 1 site" column is V2 without that annotation anywhere: 319 ms at 100
modules, with `self` worth `any` in most files.

So the trade is this, and it is direct: **V2 is cheap to analyze because you
write the annotation; V3 is expensive to analyze because it writes it for you.**
:::

### Which column real V2 lives in

The table above compares two V2 columns, and it's worth knowing which one
describes code that exists. Measured on a real V2 game on disk, 142 `.luau`
files under `src/`, of which 53 are the author's and 89 are the framework:

| | |
|---|---:|
| declared modules | 31 |
| declarations **with** a type annotation | **0** |
| author's files with `--!strict` | 8 of 53 |
| author's files with no mode at all | 45 of 53 |

No annotation, anywhere. And `ControllerFn` is
`(id: string, mode: Mode?) -> any` (`src/shared/Modux/Types.luau`), so `self`
is worth `any` in all 31.

The test that settles it, on a copy of the project: I replaced a call with
`self.FieldThatDoesNotExist:MadeUpMethod()` and, alongside it, added a control
error that depends on no `self` at all — `local control: number = "this is a string"`.

```
TypeError total: 2384   (before: 2384)
HitController.luau: (nothing)
```

Neither was reported, because the file doesn't declare `--!strict`.

::: danger The 36× comparison is generous to V2
The pattern the "V2, N sites" column measures — `local C: T.ModX = M.Controller("ModX")`
with `--!strict` — **does not appear once** in that project. Real V2 is in the
"1 site" column, and even that one is measured in strict, which the project
barely uses.

The sentence above ("V2 is cheap because you write the annotation") is still
right, but practice is harsher: **you don't write it**. V2 is cheap because it
isn't checking. The project carries 2,384 standing `TypeError`s and a
`number = "string"` nobody sees.

This doesn't absolve V3. The 19.5 s and the wall between 100 and 150 are real
and reproduced. It only bounds what the comparison says: it's V3 typing
everything against a V2 that, as it's actually written, types almost nothing.
:::

::: warning Don't compare this with the synthetic numbers
Analyzing that whole project takes 9.8 s, and that number goes into **no**
table on this page. It's 142 files with a network stack, `Instance` types and
89 framework files — a different load from everything being compared here. It
only says the run happened and that the injected errors didn't show up.
:::

### Autocomplete: neither one is felt

Warm median of `textDocument/completion`, 7 calls, first one discarded:

| N | V2, N sites | V3, N sites |
|---:|---:|---:|
| 10 | 5.9 ms | 0.5 ms |
| 25 | 5.3 ms | 0.5 ms |
| 50 | 5.6 ms | 0.7 ms |
| 100 | 6.3 ms | 0.9 ms |

Both are far below what anyone perceives while typing, and neither grows with N
in any meaningful way.

::: warning Don't read this as "V3 is 7× faster"
The two surfaces are different sizes: V2's `self` returns 17 members at that
point and V3's returns 5, because in V3 the framework's methods arrive through
the metatable. Fewer items to assemble is less work.

What the table does support is more modest and more useful: **V3's wall is the
batch `analyze`, not the typing.** What feels 19 seconds is CI, not the person
writing.
:::

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
| V2, 1 site | 69 ms |

::: warning Below ~500 ms, don't trust the decimal
The two tables above come from different runs, each with its own baseline. The
same `v2` at N=100 shows up as 69 ms in one and 319 ms in the other — not because
it changed, but because subtracting a 1.8 s constant from a 1.9 s total leaves a
remainder with an enormous relative error.

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

## What V3 buys with that

The analysis cost is the bad side of the trade. The good side is measurable too.

### Generated surface

Real projects, each in its own repository, counting only what the generator
writes:

| | modules | generated files | lines | bytes | per module |
|---|---:|---:|---:|---:|---:|
| Modux V2 | 13 | 9 | 1,142 | 38,967 | 2,998 B |
| Modux V3 (template) | 11 | 16 | 291 | 8,470 | **770 B** |

V2 concentrates everything in a few large files: `CoreTypes.luau` at 351 lines,
`ExtraTypes.luau` at 277, `ComponentTypes.luau` at 138. Each of those re-declares
the full alias list at the top. V3 spreads it into one small leaf per module, and
the leaf carries only that module's public surface.

That is **3.9× fewer generated bytes per module**, and it is what shows up in the
diff when you rename a method.

### The generation loop

V2's Watcher is TypeScript and regenerates the whole project on every change:
`generateTypes` with a median of **967 ms** across 13 modules, plus 400 ms of
debounce — that is **~1.37 s per save** before the type is right on screen. V3's
`modux` is a binary and writes per module.

That's the difference between "the type appears" and "the type appears a second
and a half from now", and it's the one felt all day — unlike `analyze`, which is
paid once per commit.

### Tooling absent

Deleting the generated types and analyzing what's left: V2 reports **1,632**
`TypeError`s, V3 reports **15**. An absolute number, not normalized by project
size, so it's good for the order of magnitude and nothing else: in V2 the
hand-written code depends on the generated types to compile; in V3 it barely
does.

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
BENCH_REPS=5 BENCH_ESTILOS=v2sites,v3sites python tools/bench/bench_estilos.py 200
```

Requirements and what each environment variable does are in the
[harness README](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench).

## What was not measured

- **Studio.** Everything here runs on the command-line `luau-lsp`. The editor has
  its own cache and its own scheduling, and it is the final verdict.
- **Real project against real project.** The V2 on disk has 13 modules, a
  networking stack and `Instance` types; V3 carries a different load. Comparing
  them head to head would measure the difference in content, not in strategy.
  That's why everything comparing V2 and V3 on this page is synthetic and load-
  matched.
- **Memory.** Neither analysis nor runtime.
- **N above 200.** There is an older measurement suggesting V3 wins again near
  N=1000, when V2's `Import` union itself turns O(N²). It was not redone with
  this harness and does not appear here — and in any case V3 already fails to
  compile at N=150, so a comparison in that range would be academic.
