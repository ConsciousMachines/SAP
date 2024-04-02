# Digital Design

My journey into computer engineering started when, as a *Data Science Professional*, I realized I have no idea what happens when I press enter in the Python interpreter to train my fancy deep learning model. At that point I started researching how everything works under the hood: programming languages, interpreters, compilers, operating systems, which eventually led me to the lowest level of all, the hardware. 

I read 4 books on digital design: 
- `Digital Computer Electronics` by Albert Paul Malvino because it discusses a simple CPU from decades ago, when things were so simple that a single human can understand everything on a chip.
- `Digital Design and Computer Architecture` by Harris & Harris because it provides Verilog code together with the circuits for a pipelined CPU.
- `Computer Principles and Design in Verilog HDL` by Yamin Li, because it continues where Harris left off, and adds features like interrupts, floating point units, multi-threading, and multi-core processors to the Verilog code. 
- `FPGA Prototyping by SystemVerilog Examples` by Pong Chu because it shows how to make all the things outside of the CPU: buses, drivers, and link together the hardware and the software.

Together, these books give me a good enough idea of what is going on underneath, to the point I can approximate how many cycles a line of code will take. 

Most importantly, I learned what `C` constructs such as loops, conditional statements, and function calls look like in assembly, and how they are processed by the pipeline, which helps with writing performant code.  

# Pipelined Processor with Interrupts

After understanding pipelined processors, the concept of *interrupts* has shown me that it is responsible for a lot of the `magic` that computers seem to do, such as multi-tasking, interfacing with the physical world, and running operating systems. At this point I felt there are no more secrets to uncover about hardware, and I can return to studying Deep Learning. 

![alt text](https://github.com/ConsciousMachines/SAP/blob/main/img/img_1.png)

# SAP

This is my interpretation of SAP from Albert Paul Malvino's digital design textbook. So far got SAP-1 and SAP-2 working. For SAP-2, I added some bonus features:
1. 8-bit everything
2. there are two muxes before the ALU, the top mux chooses between registers A/B/C and the bottom mux chooses between registers T/B/C or contant 1 (for inc / dec). This allows the ALU operations to happen in 4 clock cycles, otherwise we'd waste another clock cycle moving stuff around. 
3. there is a nifty assembler in Python to generate tests.

here is a program:
```
    jz      ; the ALU starts at 0 so we jump
    d
d:
    inr a   ; increment A, ALU becomes 1, we jump again
    jnz
    2
2: 
    dcr a   ; A becomes 0, we jump again
    jz
    b
b:
    inr a   ; last line
```

![alt text](https://github.com/ConsciousMachines/SAP/blob/main/img/img_2.png)
