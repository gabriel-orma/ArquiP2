# prog_flush.s -- CONTROL HAZARD: branch tomado -> flush de 2 instrucciones.
# El salto se resuelve en EX; las 2 instrucciones ya traidas detras del beq
# (el 'veneno') deben anularse.
#
# addr  instruccion          efecto
# 0x00  addi x1, x0, 5       x1 = 5
# 0x04  addi x2, x0, 5       x2 = 5
# 0x08  beq  x1, x2, 12      si x1==x2 salta a 0x14 (salta siempre: 5==5)
# 0x0C  addi x1, x0, 99      VENENO: debe anularse (flush)
# 0x10  addi x1, x0, 77      VENENO: debe anularse (flush)
# 0x14  sw   x1, 100(x0)     Mem[100] = 5   (x1 intacto si el flush funciona)
#
# EXITO: Mem[100] = 5. Si el flush fallara, x1 valdria 77 y se escribiria 77.
