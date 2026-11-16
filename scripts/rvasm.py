#!/usr/bin/env python3
# Mini-ensamblador RV32I para el subconjunto soportado por el proyecto.
# Instrucciones: addi add sub and or slt andi ori slti lw sw beq jal (+ nop)
# Uso: python rvasm.py entrada.s salida.dat
import sys, re

def reg(r):
    r = r.strip().lower()
    assert r[0] == 'x', f"registro malo: {r}"
    return int(r[1:])

def R(f7, rs2, rs1, f3, rd):  return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0x33
def I(imm, rs1, f3, rd, op):  return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(imm, rs2, rs1, f3):
    imm&=0xFFF
    return ((imm>>5)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0x23
def B(imm, rs2, rs1, f3):
    imm&=0x1FFF
    return (((imm>>12)&1)<<31)|(((imm>>5)&0x3F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(((imm>>1)&0xF)<<8)|(((imm>>11)&1)<<7)|0x63
def J(imm, rd):
    imm&=0x1FFFFF
    return (((imm>>20)&1)<<31)|(((imm>>1)&0x3FF)<<21)|(((imm>>11)&1)<<20)|(((imm>>12)&0xFF)<<12)|(rd<<7)|0x6F

def main():
    src, out = sys.argv[1], sys.argv[2]
    lines=[]
    for raw in open(src):
        raw = raw.split('#')[0].split('//')[0].strip()
        if raw: lines.append(raw)
    # pase 1: etiquetas
    labels={}; addr=0; prog=[]
    for ln in lines:
        m=re.match(r'^(\w+):\s*(.*)$', ln)
        if m:
            labels[m.group(1)]=addr
            ln=m.group(2).strip()
            if not ln: continue
        prog.append((addr, ln)); addr+=4
    # pase 2: codificar
    words=[]
    for a, ln in prog:
        parts=re.split(r'[\s,]+', ln)
        op=parts[0].lower()
        def imm_or_label(tok):
            return labels[tok]-a if tok in labels else int(tok,0)
        if op=='nop': w=I(0,0,0,0,0x13)
        elif op=='addi': w=I(int(parts[3],0), reg(parts[2]),0b000,reg(parts[1]),0x13)
        elif op=='andi': w=I(int(parts[3],0), reg(parts[2]),0b111,reg(parts[1]),0x13)
        elif op=='ori':  w=I(int(parts[3],0), reg(parts[2]),0b110,reg(parts[1]),0x13)
        elif op=='slti': w=I(int(parts[3],0), reg(parts[2]),0b010,reg(parts[1]),0x13)
        elif op=='add':  w=R(0,reg(parts[3]),reg(parts[2]),0b000,reg(parts[1]))
        elif op=='sub':  w=R(0x20,reg(parts[3]),reg(parts[2]),0b000,reg(parts[1]))
        elif op=='and':  w=R(0,reg(parts[3]),reg(parts[2]),0b111,reg(parts[1]))
        elif op=='or':   w=R(0,reg(parts[3]),reg(parts[2]),0b110,reg(parts[1]))
        elif op=='slt':  w=R(0,reg(parts[3]),reg(parts[2]),0b010,reg(parts[1]))
        elif op=='lw':   # lw rd, imm(rs1)
            m=re.match(r'(-?\w+)\((x\d+)\)', parts[2]); w=I(int(m.group(1),0),reg(m.group(2)),0b010,reg(parts[1]),0x03)
        elif op=='sw':   # sw rs2, imm(rs1)
            m=re.match(r'(-?\w+)\((x\d+)\)', parts[2]); w=S(int(m.group(1),0),reg(parts[1]),reg(m.group(2)),0b010)
        elif op=='beq':  w=B(imm_or_label(parts[3]), reg(parts[2]), reg(parts[1]), 0b000)
        elif op=='jal':  w=J(imm_or_label(parts[2]), reg(parts[1]))
        else: raise ValueError(f"instruccion no soportada: {op} ({ln})")
        words.append(w & 0xFFFFFFFF)
    with open(out,'w') as f:
        for w in words: f.write(f"{w:08x}\n")
    print(f"{out}: {len(words)} instrucciones")

if __name__=='__main__': main()
