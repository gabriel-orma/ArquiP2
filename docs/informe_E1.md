# Informe E1 — Pipeline de 5 etapas (Configuración A)

> Documento vivo: se va completando a medida que se construye y verifica cada parte.
> Verificación con **Icarus Verilog**; la presentación final será en Vivado (no probado aquí).

---

## 1. Objetivo de E1

Transformar el **single-cycle** RV32I en un **pipeline de 5 etapas** (IF, ID, EX, MEM, WB)
con **forwarding**, **stalling** y **flushing**, manteniendo el **mismo resultado funcional**
que el single-cycle. Esta es la **Configuración A** del proyecto.

Idea central: en vez de ejecutar 1 instrucción por ciclo (largo), se **solapan** hasta 5
instrucciones, una en cada etapa, como una línea de montaje. El resultado es el mismo,
pero el throughput sube (hacia ~1 instrucción terminada por ciclo).

---

## 2. Del single-cycle al pipeline (relación con el diagrama)

El datapath es **el mismo** del single-cycle, pero **cortado en 5 etapas** por medio de
**4 registros de pipeline** (las barras verticales del diagrama):

```
 IF        | ID          | EX            | MEM          | WB
 (Fetch)   | (Decode)    | (Execute)     | (Memory)     | (Writeback)
-----------+-------------+---------------+--------------+-----------
 PC, imem  | regfile,    | srcbmux, ALU, | dmem         | resultmux
           | extend      | branch resolve|              |
           ↑             ↑               ↑              ↑
        IF/ID         ID/EX           EX/MEM         MEM/WB   ← registros de pipeline
```

### Convención de nombres (importante para leer el diagrama)
Cada señal lleva como sufijo **la letra de la etapa** en la que está en ese momento:

| Sufijo | Etapa | Ejemplo |
|---|---|---|
| **F** | Fetch | `PCF`, `PCPlus4F` |
| **D** | Decode | `InstrD`, `ImmExtD` |
| **E** | Execute | `RD1E`, `SrcAE`, `ALUResultE` |
| **M** | Memory | `ALUResultM`, `WriteDataM` |
| **W** | Writeback | `ReadDataW`, `ResultW` |

Así, una misma señal (p. ej. `PCPlus4`) aparece como `PCPlus4F → PCPlus4D → PCPlus4E →
PCPlus4M → PCPlus4W` a medida que viaja por los registros de pipeline hasta la etapa que la usa.

---

## 3. Módulos nuevos

### 3.1 Registros de pipeline (`flopenr`, `floprc`, `flopenrc`)

**Por qué hacen falta:** el single-cycle solo tiene `flopr` (flip-flop con reset). Los registros
de pipeline necesitan además:
- **enable** → para **congelar** una etapa cuando hay un *stall* (load-use).
- **clear**  → para **limpiar** una etapa cuando hay un *flush* (branch tomado) o una burbuja.

Por eso se crean 3 variantes de `flopr` (todas en Verilog-2001, mismo estilo que el original):

| Módulo | Entradas extra | Qué hace | Dónde se usa |
|---|---|---|---|
| `flopenr` | `en` | si `en=0`, **conserva** (stall) | registro PC, registro IF/ID |
| `floprc` | `clear` | si `clear=1`, **pone 0** (flush/burbuja) | registro ID/EX |
| `flopenrc` | `en`, `clear` | ambos (prioridad: reset > clear > en) | registro IF/ID |

**Prioridad de señales** (de mayor a menor): `reset` → `clear` → `enable` → conservar.
Es decir, un *flush* (clear) gana sobre un *stall* (en): si hay que anular la instrucción,
se anula aunque también se estuviera congelando.

```verilog
// flopenr: conserva si en=0 (STALL)
always @(posedge clk or posedge reset)
  if (reset)   q <= 0;
  else if (en) q <= d;        // si en=0: q no cambia

// floprc: pone 0 si clear=1 (FLUSH / burbuja)
always @(posedge clk or posedge reset)
  if (reset)      q <= 0;
  else if (clear) q <= 0;
  else            q <= d;

// flopenrc: combina ambos (clear tiene prioridad sobre en)
always @(posedge clk or posedge reset)
  if (reset)      q <= 0;
  else if (clear) q <= 0;
  else if (en)    q <= d;
```

**Estado:** los 3 módulos compilan sin errores con Icarus (`iverilog -g2001 -tnull`). Aún no
están instanciados; se usarán al partir el datapath en etapas (paso siguiente).

---

### 3.2 Controller pipelined (`controller`, `maindec`)

El `controller` se parte del single-cycle con 2 cambios:
- **Ya no calcula `PCSrc`.** En el pipeline el salto se resuelve en **EX**, así que el
  controller solo decodifica (en ID) y expone **`Branch`** y **`Jump`** por separado,
  para propagarlos a EX.
- **`maindec`**: el `default` (y el `ImmSrc` de R-type) pasan de `x` a `0`, para que una
  instrucción desconocida —o el `0` que llena la tubería al arrancar— sea un **NOP
  inofensivo** (no escribe registros ni memoria). Evita valores `x` entre simuladores.

### 3.3 Datapath pipelined (`datapath`)

Es el datapath del single-cycle **cortado en 5 etapas** con los 4 registros de pipeline
(todos `flopr` simples en esta versión básica, sin stall/flush aún). Cada registro guarda
**datos + control** de su instrucción.

**Propagación de control:** el control se empaca en ID y se "baja" en cada etapa:

```
ID/EX  guarda 10 bits: {RegWrite, ResultSrc[2], MemWrite, Jump, Branch, ALUSrc, ALUControl[3]}
         EX usa: ALUSrc, ALUControl, Branch, Jump
EX/MEM guarda  4 bits: {RegWrite, ResultSrc[2], MemWrite}
         MEM usa: MemWrite
MEM/WB guarda  3 bits: {RegWrite, ResultSrc[2]}
         WB usa: RegWrite, ResultSrc
```
(`ImmSrc` no viaja: se usa solo en ID, en el `extend`.)

**Resolución del salto en EX:** `assign PCSrcE = (BranchE & ZeroE) | JumpE;` y
`PCTargetE = PCE + ImmExtE`, que vuelven (feedback) al mux del PC en Fetch.

**Regfile:** lee en D (`Rs1D/Rs2D`) y escribe en W (`RdW/ResultW/RegWriteW`). En esta
versión escribe en flanco de subida (suficiente mientras no haya dependencias cercanas;
se cambiará a flanco de bajada al llegar a forwarding).

### 3.4 Verificación del pipeline básico

Programa **sin dependencias** (`asm/prog_nohazard.s` → `mem/prog_nohazard.dat`): 5 `addi`
independientes + un `sw x1,100(x0)`. Como ninguna instrucción depende de una reciente, no
hay hazards y debe dar lo mismo que el single-cycle.

**Resultado (Icarus):** `PASS` — el pipeline escribe **25 en la dirección 100**, idéntico
al single-cycle. Testbench: `tb/tb_pipeline_nohazard.v`. Script: `scripts/run_pipeline.ps1`.

> Nota: este pipeline básico (sin Hazard Unit) solo es correcto con instrucciones
> independientes. El manejo de dependencias y saltos se agrega en la sección 3.5.

---

## 3.5 Hazard Unit (forwarding + stall + flush)

Es el **cerebro** de E1: un módulo combinacional (`hazardunit.v`) que resuelve los
tres tipos de hazard. Se construyó en 4 sub-pasos.

### 3.5.1 Corrección: Register File en flanco de bajada
El `regfile` ahora **escribe (WB) en flanco de bajada** (`negedge clk`) y lee (ID) en
el de subida. Así, cuando una instrucción en WB escribe un registro y otra en ID lo
lee **en el mismo ciclo** (dependencia a distancia 3), la escritura ocurre primero y
la lectura ve el valor nuevo (*write-before-read*). Cierra ese caso **sin** un tercer
cable de forwarding.

### 3.5.2 Forwarding (data hazard)
- Se **pipean `Rs1E`/`Rs2E`** (los registros que la instrucción en EX va a leer).
- Dos **muxes 3:1** (`mux3`) en las entradas de la ALU: `00`=regfile, `10`=`ALUResultM`
  (EX/MEM), `01`=`ResultW` (MEM/WB).
- La **Forwarding Unit** compara `Rs1E/Rs2E` contra `RdM`/`RdW`; si coinciden (y esa
  instrucción escribe y no es `x0`), adelanta el dato. Prioridad al más reciente (MEM
  sobre WB). Resuelve distancias 1 y 2 **sin perder ciclos**.

### 3.5.3 Stall load-use
Único caso que el forwarding no cubre (un `lw` y su consumidor pegado):
```
lwStall = ResultSrcE[0] & ((Rs1D == RdE) | (Rs2D == RdE))
StallF = StallD = lwStall          FlushE incluye lwStall (burbuja en EX)
```
Se detecta en **ID** (antes de que el consumidor entre a EX), se **congela** PC e IF/ID
(`flopenr`/`flopenrc`, `en=~Stall`) y se mete **burbuja** en ID/EX (`floprc`, `clear`).
Cuesta **1 ciclo**, tras el cual el forwarding entrega el dato.

### 3.5.4 Flush de branch/jump (control hazard)
El salto se resuelve en EX (`PCSrcE = BranchE·ZeroE + JumpE`). Si se toma, se anulan las
**2 instrucciones mal traídas**:
```
FlushD = PCSrcE                 (limpia IF/ID)
FlushE = lwStall | PCSrcE       (limpia ID/EX: burbuja de load-use O de branch)
```
`FlushD` NO incluye `lwStall` porque en un stall el registro de Decode se **congela**
(retiene al consumidor), no se flushea.

**Flops usados por registro:** PC → `flopenr` (stall); IF/ID → `flopenrc` (stall+flush);
ID/EX → `floprc` (flush). EX/MEM y MEM/WB siguen con `flopr` simple.

---

## 3.6 Programas de prueba (4 hazards) y verificación

Cada programa aísla un hazard; el testbench verifica el valor esperado en la dirección 100.

| Programa | Qué prueba | Esperado Mem[100] | Resultado (Icarus) |
|---|---|---|---|
| `prog_nohazard` | ISA sin dependencias | 25 | **PASS** |
| `prog_forward`  | forwarding (dist. 1 y 2) | 28 | **PASS** |
| `prog_stall`    | load-use (1 stall) | 14 | **PASS** |
| `prog_flush`    | branch tomado (flush ×2) | 5 | **PASS** |

Scripts: `scripts/run_pipeline.ps1 -Prog <x.dat> -Tb <tb.v>`. Testbenches en `tb/`,
programas en `mem/` (hex) y `asm/` (documentados). `prog_flush` es el más contundente:
si el flush fallara, las 2 instrucciones "veneno" ejecutarían y el valor sería 77.

---

## 3.7 Dual Fetch + Dual Decode (preliminar)

Boceto del front-end dual-issue (en `src/dual_issue/`):
- `imem2.v`: memoria de instrucciones con **2 puertos** (lee PC y PC+4) → dual fetch.
- `dualfetchdecode.v`: trae 2 instrucciones, el PC avanza **+8**, y las decodifica con
  **2 instancias del `controller`** (reutilizado) → dual decode.

**Alcance E1 (importante):** es un **boceto**, no ejecuta. NO tiene Issue Unit, NO decide
cuántas emitir, NO maneja hazards entre vías. Eso es E2. El testbench
`tb/tb_dual_fetch_decode.v` (script `scripts/run_dual.ps1`) **PASS**: muestra las 2 vías
decodificando dos instrucciones en el mismo ciclo (p. ej. `addi x1` y `addi x2` juntas).

---

## 3.8 Estado de verificación de E1

Todo verificado con **Icarus Verilog** (no probado en Vivado desde este entorno).

```
[PASS] ISA sin dependencias   Mem[100] = 25
[PASS] Forwarding             Mem[100] = 28
[PASS] Load-use stall         Mem[100] = 14
[PASS] Flush branch           Mem[100] = 5
[PASS] Dual front-end         dual fetch + decode preliminar
Resumen: 5/5 PASAN
```

---

## Registro de cambios

| Fecha | Cambio | Verificación |
|---|---|---|
| 2026-10-29 | Rama `e1-pipeline`. Copiado `single_cycle` → `pipeline/` (base de config. A). | — |
| 2026-10-29 | Creados registros de pipeline `flopenr`, `floprc`, `flopenrc`. | Compilan OK (Icarus) |
| 2026-10-31 | `controller`/`maindec` pipelined (saca `Branch`/`Jump`; default seguro). | — |
| 2026-10-31 | `datapath` pipelined de 5 etapas (datos + control propagado). `riscvsingle` los une. | — |
| 2026-10-31 | Programa sin dependencias + testbench. | **PASS**: 25 en dir 100 (Icarus) |
| 2026-11-02 | `regfile` a flanco de bajada (corrección 2). | — |
| 2026-11-02 | `hazardunit` (forwarding + lwStall + flush); datapath con muxes de forwarding, `Rs1E/Rs2E` pipeados y flops `flopenr`/`flopenrc`/`floprc`. | — |
| 2026-11-02 | Programas `forward`/`stall`/`flush` + testbenches. | **PASS**: 28 / 14 / 5 (Icarus) |
| 2026-11-02 | Front-end dual preliminar (`imem2`, `dualfetchdecode`) + testbench. | **PASS**: decode simultáneo de 2 vías (Icarus) |
