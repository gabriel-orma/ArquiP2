# E2 Prueba 4: branch tomado + flush/anulacion de instruccion joven.
# beq x1,x2 se toma (1==1). La instruccion que sigue (addi x9,99) NO debe
# ejecutarse: se anula/flush. Si x9 termina en 99, el flush fallo.
# Esperado: Mem[100] = 42, x9 = 0 (nunca escrito)
addi x1, x0, 1
addi x2, x0, 1
beq  x1, x2, destino   # salto tomado
addi x9, x0, 99        # NO debe ejecutarse (flush/anulacion)
destino:
addi x3, x0, 42
sw   x3, 100(x0)       # Mem[100] = 42
fin: beq x0, x0, fin
