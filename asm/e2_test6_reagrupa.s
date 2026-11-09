# E2 Prueba 6: reagrupamiento tras emision parcial, orden preservado, sin
# instrucciones perdidas ni duplicadas. Cadena de RAW que fuerza emite=1
# repetido; cada no-emitida se reagrupa como lider del siguiente par.
# Esperado: Mem[100] = 5  (x3=3, x4=2, x5=4, x6=5)
addi x1, x0, 1
addi x2, x0, 2
add  x3, x1, x2      # x3 = 3
sub  x4, x3, x1      # RAW con x3 -> emite 1; x4 = 2
add  x5, x4, x2      # RAW con x4 -> emite 1; x5 = 4
add  x6, x5, x1      # RAW con x5 -> emite 1; x6 = 5
sw   x6, 100(x0)     # Mem[100] = 5
fin: beq x0, x0, fin
