# Proyecto 2: Procesador RISC-V RV32I Dual-Issue In-Order

> Documento de contexto y flujo de trabajo para Claude Code.
> Colócalo como `CLAUDE.md` en la raíz del repositorio.

## 1. Objetivo

Partiendo del single-cycle RV32I que entrega el curso (`SingleCycle_26II`), construir:

1. **Configuración A:** pipeline Single-Issue de 5 etapas (IF, ID, EX, MEM, WB) con forwarding, stalling y flushing.
2. **Configuración B:** procesador **Dual-Issue in-order** (hasta 2 instrucciones por ciclo, sin Out-of-Order, sin Tomasulo, sin renombramiento).
3. **Configuración C:** B + **una optimización microarquitectónica** aprobada por el profesor (p. ej. predictor de 2 bits, BTB, Instruction Queue, caché).

Se comparan A, B y C con dos programas (uno propio en Assembly y uno del profesor): instrucciones retiradas, ciclos, IPC, CPI y speedup. Las tres deben dar el mismo resultado funcional.

## 2. Entregas y puntaje

| Entrega | Fecha límite | Puntos | Contenido |
|---|---|---|---|
| E1 | antes de la sesión 13.1 | 4 | Pipeline + Hazard Unit, 4 programas de prueba, Dual Fetch/Decode, datapath Dual-Issue preliminar, informe PDF |
| E2 | antes de la sesión 14.1 | 4 | Dual-Issue completo, Issue Unit, comparación preliminar, **propuesta de optimización (sesión 14.1)** |
| EF | antes de la sesión 15.1 | 4 | Optimización, programas Assembly, A/B/C, informe final + PDF de presentación |
| Presentación | semana 15 | 8 | ~15 min exposición + 5 min preguntas; incluye demostración |

Penalizaciones: entrega tardía −1; faltar −0.5; llegar tarde −0.25. Trivias: hasta +0.5 cada una.
Hay **preguntas individuales** en cada entrega y en la presentación: el usuario debe poder explicar todo.

## 3. Restricciones del diseño (del enunciado)

- Máximo por ciclo: 2 operaciones ALU, 1 acceso a memoria de datos, 1 branch.
- Register File con **4 lecturas y 2 escrituras** por ciclo; resolver escrituras simultáneas al mismo registro.
- Un solo puerto de memoria de datos y una sola unidad de resolución de branches.
- **Issue Unit:** decide emitir 2, 1 o 0 instrucciones según RAW, conflictos estructurales, memoria y saltos, respetando el orden del programa. La instrucción no emitida se **conserva** (sin perder ni duplicar).
- Branch en cualquier posición del par: si es la 1.ª y se toma, se anula la 2.ª; si es la 2.ª, la 1.ª se conserva.
- La optimización no puede ser un requisito obligatorio ni un cambio solo en el Assembly.

## 4. Punto de partida: single-cycle entregado

Archivos (Verilog): `top`, `riscvsingle`, `controller`, `maindec`, `aludec`, `datapath`, `alu`, `regfile`, `extend`, `imem`, `dmem`, `flopr`, `mux2`, `mux3`, `adder`, `testbench`, `riscvtest.dat`.

- Instrucciones soportadas: `add, sub, and, or, slt, addi, andi, ori, slti, lw, sw, beq, jal`.
- **No soporta:** `bne, blt/bge, lui, auipc, jalr, xor, lb/lh/sb/sh`. `sll/srl` existen en la ALU pero `aludec` no los genera. Confirmar con el profesor si se esperan más instrucciones.
- `regfile`: 2R/1W, escribe en flanco de subida, `x0` cableado a 0.
- `imem` y `dmem`: 64 palabras; `imem` carga `riscvtest.dat` con `$readmemh` (ruta relativa).
- `PCSrc = Branch & Zero | Jump` se resuelve en el mismo ciclo.
- `WriteData` es directamente `rd2` del regfile.
- Testbench: éxito si se escribe 25 en la dirección 100; usa `$stop`; **no genera VCD**.

### Cambios necesarios para el pipeline

1. Registros de pipeline con **enable** (stall) y **clear** (flush); hoy solo existe `flopr`.
2. Separar el datapath por etapas y propagar control (`RegWrite, MemWrite, ResultSrc, ALUSrc, Branch, Jump, ALUControl`, `rd`, `PC+4`).
3. Resolver branch/jump en EX; flush de IF/ID e ID/EX.
4. Regfile: escribir en flanco de bajada o bypass interno (WB y ID en el mismo ciclo).
5. Separar `WriteData` de `rd2` (forwarding también para el dato de `sw`).
6. Hazard Unit: forwarding (EX/MEM y MEM/WB hacia EX, nunca a `x0`, prioridad al más reciente), stall load-use, flush.
7. Congelar y guardar una copia del pipeline Single-Issue (configuración A).

## 5. Entorno de trabajo y flujo

**Desarrollo y verificación (aquí, con Claude Code):** Icarus Verilog + GTKWave, editor VS Code.
**Presentación (en clase):** debe hacerse en **Vivado** (simulación behavioral con xsim). Esto lo indicó el usuario; **los PDFs del curso no lo mencionan**, confirmar con el profesor.

Flujo:

1. Se desarrolla y verifica con Icarus. Claude Code compila y corre los tests aquí antes de entregar código.
2. Antes de cada exposición, el usuario pide el **paquete Vivado** (sección 8).
3. El usuario lo prueba en su PC con Vivado y reporta errores.
4. En clase se ejecuta el script y se muestra la simulación.

Claude Code **no puede ejecutar Vivado**: no debe afirmar que el paquete Vivado fue probado. Debe decir qué verificó (Icarus) y qué no (Vivado).

## 6. Reglas para el código

- **Verilog-2001 estándar**, sin SystemVerilog ni construcciones exclusivas de Icarus, para que corra igual en Vivado (xsim).
- Todo registro con reset o valor inicial (evitar `x` distintos entre simuladores).
- Módulos pequeños y separados (hazard unit, forwarding unit, issue unit), pensando en duplicar la vía en E2.
- Rutas de `$readmemh` sin directorios (solo el nombre del archivo) y ejecución desde una carpeta conocida; documentar dónde deben estar los `.mem`.
- Cada testbench debe incluir `$dumpfile` y `$dumpvars`, y terminar con `$finish` y un mensaje claro de PASS/FAIL.
- Mantener nombres de señales del single-cycle original cuando sea posible.

## 7. Estructura de carpetas sugerida

```
proyecto/
├── CLAUDE.md
├── src/
│   ├── single_cycle/      # copia intacta del código entregado
│   ├── pipeline/          # configuración A (congelada tras E1)
│   ├── dual_issue/        # configuración B
│   └── dual_issue_opt/    # configuración C
├── tb/                    # testbenches
├── mem/                   # programas .mem / .dat
├── asm/                   # programas Assembly
├── scripts/               # run_tests.sh, scripts Tcl de Vivado
├── vivado/                # paquete generado para la presentación
└── docs/                  # informes, notas, capturas
```

## 8. Paquete Vivado (antes de cada exposición)

Cuando el usuario lo pida, generar en `vivado/`:

- Copia de los fuentes `.v`, testbenches y `.mem` de la configuración a presentar.
- Un script **`crear_proyecto.tcl`** que: cree el proyecto (parte FPGA cualquiera), agregue fuentes de diseño y de simulación, defina el testbench como top, copie los `.mem` a la carpeta de simulación, ajuste el tiempo de simulación y agregue a la waveform las señales relevantes.
- Instrucciones de uso (`source crear_proyecto.tcl` desde la consola Tcl de Vivado, o `vivado -mode batch -source ...`).
- **Preferir script a un `.xpr` ya hecho:** un `.xpr` trae rutas absolutas y depende de la versión de Vivado.
- Lista de señales a mostrar por demostración (emisión simultánea, hazards, reagrupamiento, optimización).
- Aviso explícito de que el paquete no se probó en Vivado desde este entorno.

Riesgos conocidos al pasar de Icarus a Vivado: ruta de `$readmemh`, valores `x` sin reset, tiempo de simulación por defecto (1000 ns), señales internas no visibles por defecto.

## 9. Plan por fases

**Fase 0:** instalar Icarus + GTKWave (y Vivado, instalador web), estructura de carpetas, Git, compilar el single-cycle y verificar que pasa su testbench.

**E1:** pipeline de 5 etapas → forwarding → stall load-use → flush → 4 programas (ISA sin dependencias, forwarding, stalling, flushing) con `.mem` y testbench → Dual Fetch, Dual Decode, datapath preliminar → informe con waveforms **interpretadas**.

**E2:** segunda vía y 2 ALU → Regfile 4R/2W → **Issue Unit** (escribir primero las reglas de emisión en papel) → reagrupamiento → Hazard Unit ampliada → branches en 1.ª y 2.ª posición → pruebas (2 ALU independientes, RAW entre vías, load-use, conflicto de memoria, branch en ambas posiciones, 2 escrituras al regfile, reagrupamiento) → comparación preliminar → propuesta de optimización para la sesión 14.1 (nombre, limitación que resuelve, modificación, módulos afectados, métrica).

**EF:** optimización + tests propios → programa Assembly propio (con complejidad real) y programa del profesor, **sin modificarlos** → medir A, B, C con criterios idénticos → verificar equivalencia funcional → informe final y PDF de presentación.

## 10. Verificación (obligatoria antes de entregar código)

- Compilar y simular con Icarus aquí; reportar resultado real.
- Comparar el estado final (registros y memoria) del pipeline contra el single-cycle original en los mismos programas.
- Un test por cada hazard, además de pruebas combinadas (forwarding + stall + flush).
- Opcional: modelo de referencia RV32I en Python para comparar resultados automáticamente.
- Decir con claridad qué se probó y qué no. No afirmar que "todo funciona" sin evidencia.

## 11. Modo de trabajo con el usuario

El usuario quiere **entender lo suficiente para explicarlo**, con el menor tiempo posible, y tiene evaluación individual. Por eso:

- Trabajar por **bloques de 30 a 45 minutos**: (1) escribir y probar el módulo, (2) explicar en ~5 minutos qué hace con un ejemplo ciclo por ciclo, (3) hacer 3 preguntas cortas, (4) avanzar solo si responde bien.
- Explicar con ejemplos concretos de 2 o 3 instrucciones (p. ej. `lw x1` seguido de `add x2, x1, x3`).
- Cuando algo falle, explicar la causa del bug en lenguaje simple, no solo corregirlo.
- Priorizar la comprensión de la **Issue Unit** y del **reagrupamiento** (lo más preguntado y lo más difícil).
- Preparar explicaciones guiadas de cada waveform para el informe.
- Marcar toda ambigüedad del enunciado en lugar de decidirla en silencio.

Estimación acordada de estudio del usuario (versión rápida): E1 6 a 10 h, E2 10 a 16 h, EF 6 a 10 h, presentación 3 a 5 h (unas 25 a 40 h en total). Son estimaciones, no requisitos.

## 12. Preferencia del usuario

El usuario pidió que cada respuesta termine con una sección **"Prompt Improvement"** (cómo mejorar su redacción, versión técnicamente mejorada de su mensaje, y aclaración opcional). Aplica a todas las respuestas, y va siempre al final.

## 13. Preguntas abiertas para el profesor

- ¿La demostración debe correr en vivo en Vivado, o basta con mostrar waveforms?
- ¿Se esperan instrucciones adicionales además de las 13 que soporta el single-cycle (`bne`, `jalr`, `lui`...)?
- ¿Tamaño de memorias (hoy 64 palabras) y formato del programa del profesor?
- ¿Número de integrantes y fechas exactas de E1, E2, EF y presentación?
