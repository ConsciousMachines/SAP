

opcodes = {
    "INR A"     :"3c",
    "INR B"     :"04",
    "INR C"     :"0c",
    "DCR A"     :"3d",
    "DCR B"     :"05",
    "DCR C"     :"0d",
    "ADD B"     :"80",
    "ADD C"     :"81",
    "SUB B"     :"90",
    "SUB C"     :"91",
    "ANA B"     :"a0",
    "ANA C"     :"a1",
    "ORA B"     :"b0",
    "ORA C"     :"b1",
    "XRA B"     :"a8",
    "XRA C"     :"a9",
    "RAL"       :"17",
    "RAR"       :"1f",
    "CMA"       :"2f",
    "NOP"       :"00",
    "MOV A, B"  :"78",
    "MOV A, C"  :"79",
    "MOV B, A"  :"47",
    "MOV B, C"  :"41",
    "MOV C, A"  :"4f",
    "MOV C, B"  :"48",
    "HLT"       :"76",
    "LDA"       :"3a",
    "STA"       :"32",
    "MVI A"     :"3e",
    "MVI B"     :"06",
    "MVI C"     :"0e",
    "ANI"       :"e6",
    "ORI"       :"f6",
    "XRI"       :"ee",
    "JMP"       :"c3",
    "JM"        :"fa",
    "JNZ"       :"c2",
    "JZ"        :"ca",
}

def assemble(prog):
    lines = [i.split(';')[0].strip().upper() for i in prog.split('\n') if len(i) > 0]
    i = 0
    obj = ['00000000\n' for i in range(16)]
    for line in lines:
        if line.__contains__(':'):
            i = int(line.split(':')[0], 16)
            continue 
        if opcodes.__contains__(line):
            obj[i] =  bin(int(opcodes[line], 16)).replace('0b','').zfill(8) + '\n'
        else:
            obj[i] = bin(int(line, 16)).replace('0b','').zfill(8) + '\n'
        i += 1 

    #print(''.join(obj)) # print object code 
    print(''.join([f"{hex(i).replace('0x','')}: {obj[i]}" for i in range(len(obj))])) # with line numbers
    return ''.join(obj)



prog = '''
    jnz      ; if not zero, jump to address A
    a        ; dont do anything since 0 in a_reg
    mvi a    ; move 1 into a_reg
    1   
    jnz      ; now we jump
    a
a:
    mvi a
    2
'''


prog = '''
    inr a   ; make a_reg = 1
    inr b   ; make b_reg = 1
    add b   ; A = 2
    jnz 
    c
c: 
    ani
    aa
'''

prog = '''
    inr a
    inr b 
    inr c
    dcr a
    dcr b 
    dcr c
'''

prog = '''
    inr b
    inr c
    inr c
    add b
    add c
    sub b
    sub c
'''

prog = '''
    inr b 
    ana b
    inr a
    ana b
    ana c
    inr c 
    ana c
'''

prog = '''
    inr c 
    inr c
    inr b
    ora b
    ora c
'''

prog = '''
    inr b
    inr c
    inr c
    xra b
    xra c
'''

prog = '''
    inr a
    ral
    ral
    ral
    rar
    rar
    rar
'''

prog = '''
    cma 
    mov b, a
    mov c, b
    cma
    mov c, a
    mov b, c
'''

prog = '''
    mvi a
    e
    sta
    b
    mov a, b
    lda
    b
'''

prog = '''
    mvi a
    5
    ani
    a
'''

prog = '''
    mvi a
    5
    ori 
    a
    xri 
    aa
'''

prog = '''
0:
    jmp
    e
e:
    jmp
    2
2: 
    jmp 
    c
c: 
    jmp
    4
4: 
    jmp
    a
a: 
    jmp
    6
6: 
    jmp
    8
8: 
    jmp 
    8
'''

prog = '''
    jmp
    0
'''

prog = '''
    jz
    d
d:
    inr a
    jnz
    2
2: 
    dcr a
    jz
    b
b:
    inr a
'''

prog = '''
    jz       ; test jumps for fun
    5
5: 
    inr a    ; make a 1 
    ral      ; make a 2 
    mov b, a ; put 2 into b
    ral      ; make a 4
    ral      ; make a 8
    add b    ; add 2 + 8 = 1010
    hlt
'''

prog = '''
    mvi b   ; put 255 into b
    ff
2: 
    lda     ; put adr e into reg a (starts w 0)
    e
    inr a   ; increment
    sta     ; put it back 
    e 
    jnz     ; if not equal to b_reg, repeat
    2
    jmp     ; restart loop
    2
'''

# write to file
if True:
    x = assemble(prog)
    mem_file = r'C:\Users\pwnag\Desktop\prog_mem.txt'
    with open(mem_file, 'w') as f:
        _ = f.write(x)



