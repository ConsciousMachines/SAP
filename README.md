# SAP
my interpretations of SAP from Albert Paul Malvino's digital design textbook. So far got SAP-1 and SAP-2 working. For SAP-2, I added some bonus features:
1. 8-bit everything
2. there are two muxes before the ALU, the top mux chooses between registers A/B/C and the bottom mux chooses between registers T/B/C or contant 1 (for inc / dec). This allows the ALU operations to happen in 4 clock cycles, otherwise we'd waste another clock cycle moving stuff around. 
3. there is a nifty assembler in Python to generate tests.

here is a program:
```
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
```

![alt text](https://github.com/ConsciousMachines/SAP/blob/main/Screenshot%20(96).png)
