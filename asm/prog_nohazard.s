# prog_nohazard.s  -- programa de prueba SIN dependencias cercanas ni saltos.
# Sirve para verificar el pipeline BASICO (sin hazard unit): como ninguna
# instruccion depende de una reciente, no hay hazards y debe dar el mismo
# resultado que el single-cycle.
#
# addr  instruccion            efecto
# 0x00  addi x1, x0, 25        x1 = 25
# 0x04  addi x2, x0, 1         x2 = 1   (relleno independiente)
# 0x08  addi x3, x0, 2         x3 = 2
# 0x0C  addi x4, x0, 3         x4 = 3
# 0x10  addi x5, x0, 4         x5 = 4
# 0x14  sw   x1, 100(x0)       Mem[100] = 25   (x1 se escribio 5 instr antes: sin hazard)
# (el resto de la imem es 0 = NOP seguro)
#
# EXITO: se escribe 25 en la direccion 100.
