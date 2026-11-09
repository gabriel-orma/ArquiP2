# E2 Prueba 2: RAW entre candidatas a emision + forwarding entre etapas.
# add x3 / sub x4: sub lee x3 que add escribe -> RAW intra-par -> emite 1.
# sub x4 se reagrupa y recibe x3 por forwarding.
# Esperado: Mem[100] = 40  (x3=30, x4=20, x5=40)
addi x1, x0, 10
addi x2, x0, 20
add  x3, x1, x2      # x3 = 30   (I0)
sub  x4, x3, x1      # lee x3 (RAW con I0) -> emite 1; luego forwarding de x3
add  x5, x4, x2      # x5 = 20 + 20 = 40
sw   x5, 100(x0)     # Mem[100] = 40
fin: beq x0, x0, fin
