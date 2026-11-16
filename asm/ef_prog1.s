# EF Programa 1 (propio, complejidad real): acumulacion de un arreglo.
# Inicializa a[] = {5,3,8,1,9,4} en memoria y lo suma en un bucle.
# Ejercita: ALU en 2 vias, forwarding (RAW), load-use (stall) y un bucle
# con branch de retorno tomado 5 veces (donde el predictor de C ayuda).
# Esperado: Mem[100] = 5+3+8+1+9+4 = 30. Debe ser IGUAL en A, B y C.

      # inicializar el arreglo en memoria de datos
      addi x1, x0, 5
      sw   x1, 0(x0)
      addi x1, x0, 3
      sw   x1, 4(x0)
      addi x1, x0, 8
      sw   x1, 8(x0)
      addi x1, x0, 1
      sw   x1, 12(x0)
      addi x1, x0, 9
      sw   x1, 16(x0)
      addi x1, x0, 4
      sw   x1, 20(x0)

      # bucle de acumulacion
      addi x2, x0, 0        # suma = 0
      addi x3, x0, 0        # offset = 0
      addi x4, x0, 24       # limite = 6*4
loop:
      lw   x5, 0(x3)        # a[i]
      add  x2, x2, x5       # suma += a[i]   (load-use -> stall)
      addi x3, x3, 4        # offset += 4
      beq  x3, x4, done     # salir si offset == 24
      beq  x0, x0, loop     # repetir (backward, tomado 5 veces)
done:
      sw   x2, 100(x0)      # Mem[100] = 30
fin:  beq  x0, x0, fin      # alto
