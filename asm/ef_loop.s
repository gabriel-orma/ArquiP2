# EF: bucle para demostrar el predictor de 2 bits + BTB (config C).
# El branch de retorno (beq x0,x0,loop) se toma 7 veces: la 1ra falla (BTB vacio)
# y las siguientes se predicen bien -> C se ahorra la penalizacion de 2 ciclos.
# Esperado: x3 = 3*8 = 24, Mem[100] = 24. Debe ser IGUAL en A, B y C.
      addi x1, x0, 8       # N = 8 iteraciones
      addi x3, x0, 0       # acumulador
loop:
      addi x3, x3, 3       # x3 += 3
      addi x1, x1, -1      # x1 -= 1
      beq  x1, x0, done    # salir si x1 == 0 (forward, tomado 1 vez)
      beq  x0, x0, loop    # volver al inicio (backward, tomado 7 veces)
done:
      addi x4, x0, 100     # direccion base
      sw   x3, 0(x4)       # Mem[100] = 24
fin:  beq  x0, x0, fin     # alto
