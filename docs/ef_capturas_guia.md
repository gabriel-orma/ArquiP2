# Guía de capturas para el informe EF — ciclos y tiempos exactos

Verificado en Icarus. El tiempo es igual en Vivado y GTKWave (reset a 22 ns, reloj de 10 ns).
Conversión: **tiempo (ns) = 20 + 10 · ciclo**.

En Vivado, tras Run Simulation, arrastra al visor las señales del testbench (ya están declaradas):
`em`, `predS`, `mispS`, `stallS`, `annulS`, y la traza `t0E` / `t1E` (pon el radix en ASCII para verlas como texto).

---

## CAPTURA 2 — Cierre y equivalencia funcional
- Testbench: **tb_C_prof**
- Dónde resaltar: final, **PC=356 sostenido, ~ciclo 408 → t ≈ 4100 ns**.
- Señales: `done`, `PCnow`, `MemWrite`, `DataAdr`, `WriteData`.
- Debajo: la memoria final M[x1+0..52] = `11 5 12 7 16 23 24 18 24 74 4 0 1 1` coincide con la referencia del profesor → las 3 configuraciones dan el mismo resultado.

## CAPTURA 3 — Doble emisión (IPC → 2)
- Testbench: **tb_C_showcase**
- Dónde resaltar: **ciclos 6 a 12 → t = 80 a 140 ns**. Marca el **ciclo 8 (t = 100 ns)**: `v0E=and`, `v1E=or`, `em=2`.
- Señales: `em` (=2), `t0E`, `t1E`.
- Debajo: dos instrucciones ALU independientes se ejecutan en el mismo ciclo; `em=2` sostenido = el procesador retira 2/ciclo.

## CAPTURA 4 — Predicción y aprendizaje del BTB (LA clave)
- Testbench: **tb_C_loop**
- Dónde resaltar DOS puntos juntos:
  - **ciclo 7 (t = 90 ns): `MISPRED`** — primera vez que el salto de retorno se toma; el BTB está frío → 1 flush.
  - **ciclo 9 en adelante (t = 110 ns … 330 ns): `PREDICE` continuo sin un solo MISPRED** — el BTB ya aprendió el salto.
  - (opcional) **ciclo 35 (t = 370 ns): `MISPRED`** final al salir del bucle (inevitable).
- Señales: `predS` (PREDICE), `mispS` (MISPRED), `hit0S`.
- Debajo: un único fallo al inicio y luego predicción perfecta; cada `PREDICE` acertado es un flush que la config B sí pagaba.

## CAPTURA 5 — Stall load-use
- Testbench: **tb_C_prof**
- Dónde resaltar: **ciclo 18 (t = 200 ns): `stallS=1`, `em=0`**. Un ciclo antes (c17, t=190 ns) `v1E=lw`.
- Señales: `stallS`, `em`, `t0E`, `t1E`.
- Debajo: un `lw` seguido de quien usa el dato obliga a congelar un ciclo (burbuja); es el único hazard que el forwarding no puede evitar.

## CAPTURA 6 — Reagrupamiento (emisión parcial)
- Testbench: **tb_C_showcase**
- Dónde resaltar: **ciclo 13 (t = 150 ns): `em=1`, `v1E=bubble`**.
- Señales: `em` (cae de 2 a 1), `t0E`, `t1E`.
- Debajo: cuando el par no se puede emitir junto (conflicto/dependencia), se emite solo la vía 0 y la vía 1 se conserva para el siguiente ciclo (no se pierde ni se duplica).

## CAPTURA 7 — Branch tomado: flush + anulación de vía 1
- Testbench: **tb_C_prof**
- Dónde resaltar: **ciclo 39 (t = 410 ns): `mispS=1` y `annulS=1`** (salto frío, aún sin BTB).
  Contrasta con **ciclo 45 (t = 470 ns): `predS=1` + `annulS=1` sin `mispS`** (ya predicho: anula la vía 1 pero sin flush).
- Señales: `mispS`, `annulS`, `predS`.
- Debajo: el salto en la vía 0 anula la vía 1 del par; en frío cuesta un flush, pero una vez aprendido (c45) el BTB predice y ya no hay flush.

---

### Resumen rápido (ciclo → ns)
| Captura | Testbench | Ciclo | Tiempo | Señal clave |
|---|---|---|---|---|
| 3 Doble emisión | tb_C_showcase | 6–12 | 80–140 ns | em=2 |
| 4 BTB aprende | tb_C_loop | 7 / 9+ / 35 | 90 / 110–330 / 370 ns | mispS→predS |
| 5 Load-use stall | tb_C_prof | 18 | 200 ns | stallS, em=0 |
| 6 Reagrupamiento | tb_C_showcase | 13 | 150 ns | em=1 |
| 7 Flush + annul | tb_C_prof | 39 vs 45 | 410 vs 470 ns | mispS/annulS vs predS |
| 2 Cierre | tb_C_prof | ~408 | ~4100 ns | done + memoria |
