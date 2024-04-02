# generate test cases file


x = '''
mwreg,mrn,ern,ewreg,em2reg,mm2reg,rsrtequ,func,op,rs,rt,
                 wreg,m2reg,wmem,aluc,regrt,aluimm,fwda,fwdb,nostall,sext,
                 pcsrc,shift,jal
'''.split(',')
x = [i.strip() for i in x]
x 
for i in x:
    print(f'.{i}({i}),')