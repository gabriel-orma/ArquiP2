# E2 Prueba 1: dos operaciones ALU INDEPENDIENTES emitidas juntas (emite=2).
# Esperado: Mem[100] = 12  (x5=11, x6=1, x7=12)
addi x1, x0, 5
addi x2, x0, 6
addi x3, x0, 7
addi x4, x0, 8
add  x5, x1, x2      # x5 = 11
sub  x6, x4, x3      # x6 = 1   (independiente de x5 -> el par emite 2)
add  x7, x5, x6      # x7 = 12
sw   x7, 100(x0)     # Mem[100] = 12
fin: beq x0, x0, fin
