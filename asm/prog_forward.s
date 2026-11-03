# prog_forward.s -- data hazards resueltos por FORWARDING (sin stall).
# Prueba que el forwarding adelanta resultados de la ALU a distancia 1 y 2.
#
# addr  instruccion        efecto
# 0x00  addi x1, x0, 5     x1 = 5
# 0x04  addi x2, x0, 6     x2 = 6
# 0x08  add  x3, x1, x2    x3 = 11
# 0x0C  add  x4, x3, x2    x4 = 17   (x3 recien producido -> forward desde EX/MEM)
# 0x10  add  x5, x4, x3    x5 = 28   (x4 desde EX/MEM, x3 desde MEM/WB)
# 0x14  sw   x5, 100(x0)   Mem[100] = 28
#
# EXITO: Mem[100] = 28 sin ningun ciclo de stall.
