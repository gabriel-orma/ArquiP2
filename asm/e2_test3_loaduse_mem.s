# E2 Prueba 3: load-use (emite=0, stall) + conflicto del puerto de memoria.
# sw y lw son ambos memoria -> si caen en un par, memConf -> emite 1.
# add x3 usa x2 justo tras el lw -> load-use -> stall (emite 0).
# Esperado: Mem[100] = 14  (x2=7, x3=14)
addi x1, x0, 7
addi x4, x0, 0
sw   x1, 100(x0)     # Mem[100] = 7
lw   x2, 100(x0)     # x2 = 7   (sw y lw: conflicto de memoria)
add  x3, x2, x2      # usa x2 recien cargado -> load-use stall; x3 = 14
sw   x3, 100(x0)     # Mem[100] = 14
fin: beq x0, x0, fin
