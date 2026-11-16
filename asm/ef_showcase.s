# EF showcase: programa disenado para que las mejoras se vean CLARAS.
#  - Bloque de 12 operaciones ALU INDEPENDIENTES -> B las empareja de a 2 (B >> A).
#  - Todo en un BUCLE que se repite 15 veces -> el predictor de C elimina la
#    penalizacion del salto de retorno (C >> B).
# Esperado: x17 = (x1+x2)*15 = 12*15 = 180. Mem[100] = 180.
      addi x20, x0, 15       # N = iteraciones
      addi x21, x0, 0        # contador
      addi x30, x0, 1        # constante 1 (para el beq)
      addi x1,  x0, 5
      addi x2,  x0, 7
      addi x3,  x0, 3
      addi x4,  x0, 9
      addi x17, x0, 0        # acumulador
loop:
      add  x5,  x1, x2       # 12 ALU independientes: cada par (vicio0,via1) es independiente
      add  x6,  x3, x4
      sub  x7,  x2, x1
      sub  x8,  x4, x3
      and  x9,  x1, x3
      or   x10, x2, x4
      add  x11, x1, x4
      sub  x12, x4, x1
      and  x13, x2, x3
      or   x14, x1, x2
      slt  x15, x1, x2
      slt  x16, x3, x4
      add  x17, x17, x5      # acumula (dependencia pequena, 1 por iteracion)
      addi x21, x21, 1       # contador++
      slt  x25, x21, x20     # x25 = (contador < N)
      beq  x25, x30, loop    # repetir mientras contador < N (backward, tomado 14 veces)
      sw   x17, 100(x0)      # Mem[100] = 180
fin:  beq  x0, x0, fin
