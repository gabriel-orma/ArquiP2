# Proyecto 2 — RISC-V RV32I Dual-Issue

Punto de partida: single-cycle RV32I entregado por el curso (`SingleCycle_26II`).
El flujo y el plan completo estan en [`CLAUDE.md`](CLAUDE.md).

## Estado actual

- [x] **Fase 0** — Icarus Verilog + GTKWave instalados, estructura de carpetas, single-cycle compilando y pasando su testbench.
- [ ] E1 — Pipeline 5 etapas + Hazard Unit
- [ ] E2 — Dual-Issue + Issue Unit
- [ ] EF — Optimizacion + A/B/C

## Requisitos

- **Icarus Verilog 12** (instalado con `winget install Icarus.Verilog`, en `C:\iverilog`).
  Incluye `vvp` y **GTKWave** (`C:\iverilog\gtkwave\bin\gtkwave.exe`).
  > El instalador agrega `C:\iverilog\bin` al PATH, pero abre una **terminal nueva**
  > (o reinicia VS Code) para que `iverilog` quede disponible. Los scripts de abajo
  > funcionan igual aunque no este en el PATH.

## Como correr el single-cycle

Desde la raiz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_single_cycle.ps1
```

o en Git Bash:

```bash
bash scripts/run_single_cycle.sh
```

**PASS esperado:** el programa escribe `25` en la direccion `100` y se imprime
`Simulation succeeded`.

## Estructura

```
.
├── CLAUDE.md              # contexto y plan del proyecto
├── README.md
├── src/
│   ├── single_cycle/      # copia intacta del codigo entregado (baseline)
│   ├── pipeline/          # config. A (E1)
│   ├── dual_issue/        # config. B (E2)
│   └── dual_issue_opt/    # config. C (EF)
├── tb/                    # testbenches del pipeline/dual-issue
├── mem/                   # programas .mem / .dat
├── asm/                   # programas en Assembly
├── scripts/               # run_*.{ps1,sh}, Tcl de Vivado
├── vivado/                # paquete para la presentacion (generado)
└── docs/                  # informes, notas, capturas
```

## Notas

- La verificacion se hace aqui con **Icarus**. La presentacion se hace en **Vivado**
  (ver `CLAUDE.md`, seccion 8). El paquete de Vivado **no se prueba** desde este entorno.
- El single-cycle soporta solo: `add sub and or slt addi andi ori slti lw sw beq jal`.
