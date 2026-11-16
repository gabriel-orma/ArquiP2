# EF — Evaluación funcional y de rendimiento (A / B / C)

Configuraciones comparadas:
- **A** = pipeline single-issue de 5 etapas (`src/pipeline`).
- **B** = dual-issue in-order (`src/dual_issue`).
- **C** = B + **predictor de 2 bits + BTB** (`src/dual_issue_opt`).

Mediciones con Icarus Verilog (los testbenches del proyecto Vivado único
`vivado/ef_proyecto/` dan los mismos números).

## Método de medición
- **Instrucciones retiradas** = ciclos del **single-cycle** (ejecuta 1 instr/ciclo, sin
  ambigüedad). Es una propiedad del programa → **idéntico para A, B y C**.
- **Ciclos** = flancos de reloj desde `reset` hasta alcanzar la etiqueta `fin`
  (excluyendo el bucle `fin`), medidos por el testbench.
- `IPC = retiradas / ciclos`  ·  `CPI = ciclos / retiradas`  ·
  `Speedup(X→Y) = ciclos_X / ciclos_Y`.
- **Doble emisión** = % de ciclos en que el Issue Unit emite 2 (emisión bruta).
- **Precisión del predictor** = (branches − mispredicts) / branches (solo C).

## Equivalencia funcional ✔
Las tres configuraciones producen el **mismo estado** que el single-cycle en todos
los programas:
- Profesor: `M[x1+0..52]` = `11 5 12 7 16 23 24 18 24 74 4 0 1 1` (x1=1536).
- Showcase: `Mem[100] = 180`. · Propio prog1: `Mem[100] = 30`.

### Comprobación por etapa (programa del profesor)
El programa del profesor cierra cada etapa escribiendo su resultado en memoria (`sw`).
Esa palabra almacenada es la **señal de comprobación** de la etapa: si coincide con la
referencia, la etapa pasó. Las tres configuraciones (A, B, C) escriben el **mismo valor**
en cada punto, lo que verifica que el dual-issue y la optimización no alteran la semántica.

| Etapa | Qué ejercita | Dirección `M[x1+off]` | Referencia | A (single-issue) | B (dual) | C (dual+pred+BTB) | ✔ |
|---|---|---|---|---|---|---|---|
| **A** | Emisión y dependencias RAW (forwarding) | +0, +4, +8 | `11, 5, 12` | `11, 5, 12` | `11, 5, 12` | `11, 5, 12` | ✔ |
| **B** | Memoria y hazard load-use | +12, +16, +20 | `7, 16, 23` | `7, 16, 23` | `7, 16, 23` | `7, 16, 23` | ✔ |
| **C** | Bucles y branches (predictor/BTB) | +24, +28, +32 | `24, 18, 24` | `24, 18, 24` | `24, 18, 24` | `24, 18, 24` | ✔ |
| **D** | Integración (loads + branches encadenados) | +36, +40, +44, +48, +52 | `74, 4, 0, 1, 1` | `74, 4, 0, 1, 1` | `74, 4, 0, 1, 1` | `74, 4, 0, 1, 1` | ✔ |

Ciclos hasta `fin` (mismo programa): **A = 456 · B = 478 · C = 406**. El resultado
funcional es idéntico en las cuatro etapas; solo cambia el número de ciclos.

## Tabla comparativa

| Programa | Config | Ciclos | Retiradas | IPC | CPI | ×vs A | ×vs B | Doble emisión | Precisión |
|---|---|---|---|---|---|---|---|---|---|
| **Showcase** (propio) | A | 280 | 249 | 0.89 | 1.12 | 1.00 | — | — | — |
| `asm/ef_showcase.s` | B | 185 | 249 | 1.35 | 0.74 | **1.51** | 1.00 | **90%** | — |
| | **C** | **162** | 249 | **1.54** | **0.65** | **1.73** | **1.14** | 90% | **93%** |
| **Profesor** | A | 456 | 313 | 0.69 | 1.46 | 1.00 | — | — | — |
| `asm/prof_ef.s` | B | 478 | 313 | 0.65 | 1.53 | **0.95** | 1.00 | **76%** | — |
| | **C** | **406** | 313 | 0.77 | 1.30 | 1.12 | **1.18** | 74% | **67%** |
| **Propio prog1** | A | 64 | 45 | 0.70 | 1.42 | 1.00 | — | — | — |
| `asm/ef_prog1.s` | B | 57 | 45 | 0.79 | 1.27 | 1.12 | 1.00 | 72% | — |
| (load-use + memoria) | **C** | **49** | 45 | **0.92** | **1.09** | **1.31** | **1.16** | 72% | **90%** |

### Límite de IPC (programa sintético)
`asm/ef_ipc2.s` — 125 ALU independientes seguidas (sin saltos ni memoria):
**B = C = 66 ciclos → IPC = 1.894.** Muestra que te acercas al ideal de 2 pero no lo
tocas (llenado/vaciado del pipeline). No es un programa de evaluación válido (el
enunciado excluye "secuencias triviales de operaciones independientes"); sirve solo
como evidencia del techo de IPC.

## Análisis (sección 5.4)

**1. Mejora del Dual-Issue sobre el pipeline.** Cuando hay ILP (showcase), B emite 2
el **90%** de los ciclos → **IPC 1.35 (>1)** → **1.51× sobre A**. Ahí el superescalar
cumple su promesa.

**2. Causas que impiden alcanzar el IPC ideal de 2.**
- **Llenado/vaciado del pipeline:** incluso con código perfecto (`ef_ipc2`) el IPC se
  queda en 1.89 (fijo, se amortiza con programas largos).
- **Dependencias RAW intra-par:** si la 2ª instrucción usa el resultado de la 1ª, no se
  emparejan (emisión parcial → burbuja de reagrupamiento).
- **Conflicto estructural de memoria** (1 puerto) y **de branch** (1 unidad).
- **Flushes de branch:** el mayor costo en código ramoso (ver punto 3).

**3. Hallazgo: en código ramoso el problema NO es emparejar, son los flushes.**
En el programa del profesor B empareja el **76%** de los ciclos (casi sin stalls), y
aun así es **más lento que A** (0.95×). La causa: el programa tiene **88 branches** y
en B **cada salto tomado descarta las instrucciones emitidas especulativamente**;
como B busca de a 2, desperdicia el doble por flush. Por eso una emisión bruta alta
**no se traduce en velocidad**.

**4. Qué limitación ataca la optimización y su impacto.** El predictor de 2 bits + BTB
**reduce los flushes**: acierta el **67%** de los branches del profesor y el **93%**
del showcase. Resultado: **C = 1.18× sobre B** en el profesor (recupera la ventaja
sobre A: 1.12×) y **1.14× sobre B** en el showcase. Es justo lo que convierte la
emisión en rendimiento.

**5. Cuándo conviene el Dual-Issue (y cuándo no).**
- **Conviene** con ILP alta (showcase: 1.51× sobre A).
- **Estorba** con código dependiente y ramoso sin predicción (profesor: B 0.95×).
- **La optimización lo rescata** en ambos casos reduciendo las penalizaciones de salto.

**6. Mejora futura.** La **burbuja de reagrupamiento** (emisión parcial que re-busca la
vía1) sigue presente; un **Instruction Queue** que conserve la instrucción no emitida
la eliminaría, complementando al predictor.
