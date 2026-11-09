# E2 Prueba 5: dos escrituras al Register File en el mismo ciclo, incluida
# escritura simultanea al MISMO registro (gana la via 1, la mas joven).
# add x5 / addi x5: ambas escriben x5 (WAW) -> emiten juntas, gana addi (x5=7).
# Esperado: Mem[100] = 7  (si ganara la via 0, seria 100)
addi x1, x0, 100
addi x2, x0, 200     # addi x1 / addi x2: emiten 2 -> 2 escrituras el mismo ciclo
add  x5, x1, x0      # x5 = 100  (via 0)
addi x5, x0, 7       # x5 = 7    (via 1, mas joven) -> GANA
sw   x5, 100(x0)     # Mem[100] = 7
fin: beq x0, x0, fin
