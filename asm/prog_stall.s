# prog_stall.s -- LOAD-USE: el unico data hazard que necesita 1 ciclo de stall.
# Un lw seguido inmediato de una instruccion que usa el valor cargado.
#
# addr  instruccion        efecto
# 0x00  addi x1, x0, 7     x1 = 7
# 0x04  sw   x1, 96(x0)    Mem[96] = 7   (dato de x1 por forwarding)
# 0x08  lw   x2, 96(x0)    x2 = 7
# 0x0C  add  x3, x2, x2    x3 = 14   (LOAD-USE: stall 1 ciclo + forward desde WB)
# 0x10  sw   x3, 100(x0)   Mem[100] = 14
#
# EXITO: Mem[100] = 14. El 'add' se detiene 1 ciclo hasta que el lw tiene el dato.
