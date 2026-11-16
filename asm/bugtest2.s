      addi x6, x0, 200
      addi x7, x0, 1
      sw   x7, 0(x6)
      addi x4, x0, 0
      addi x10, x0, 50
      nop
loop:
      addi x10, x10, -1
      lw   x5, 0(x6)
      add  x4, x4, x5
      beq  x10, x0, done
      beq  x0, x0, loop
done: sw   x4, 100(x0)
fin:  beq  x0, x0, fin
