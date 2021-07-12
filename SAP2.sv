
// - all register transfers happen on posedge - so all the setup happens on the negedge (ring counter)
// - ring counter gets things going so half a CLK later, the posedge hits and saves new data. 
//      so the ring counter is really the clock, giving comb circuits half a CLK to propagate, and the real clock 
//      tells the registers to save the data like a snapshot of the program's progress. 
//      this satisfies setup & hold time for the incoming data for registers, when everything is driven by the ring counter.
// * REGISTERS get new values on the posedge of the clock!
// * the control signals mimic the ring counter - active from one negedge to the next. 
// * the presettable counter needs to be negedge. this is because it's not a register, rather similar to ring_count as it drives
//      the same category of circuits, in this case the control word output. 

// - i was hesitant to use signals at first. then i realized the control word is basically a unit of its own: 
//      it is driven by preset_counter which is an independent negedge clk counter. it is 0,1,2 during T1,T2,T3.
//      by T4 it depends on i_reg which gives start_address. i_reg is posedge driven, and always setup by T4. 
//      because everything that depends on the signals is either posedge driven or combinational, the signals have half a clock
//      to propagate to the registers, so it doesn't matter if it depends on the signal or the ring_counter's state, as they happen
//      in the same neg-to-neg time span. The w_bus depends on the signals and it is combinational, so signals propagate through it 
//      in the neg-to-neg time span and are ready for registers by the time the posedge hits. 
// I/O pins are either Input or Output depending on the Enable / Load signal inside. it is connected to both the chip's input + output.
// control signals load, enable, and prepare registers for the next positive clock edge. 
// - it takes 2 clocks for a memory fetch: 1 clock for MAR to fall thru to MDR, and one clock for MDR to fall thru to another reg.
// I didnt include an Lf bit which allows only certain instructions to affect the flags p.187 


/*
---- M Y   S I G N A L S
E~ - enable register to output to bus
L~ - load data into register from bus

ring_rst - reset ring_count, if instr has a nop or finish on T5, then next state is T1
Cp - count up prog_counter during state T2
Su - subtract instead of add in ALU

Mw - Memory write - if 1, put the contents of MDR at location MAR in memory (its output sets up the RAM)
        if 0, sends data to the bus after a read operation. 

JM, JNZ, JZ - these signals will be sent alone. for example, JZ is sent. if Z_flag is 1, together they say to go thru with the jump.
    so we continue to the other 3 microinstructions which are the same as those of JMP. If Z_flag is 0, we reset the ring_counter
    and it acts as a short circuit to a NOP. 

*/


// new signals: 
// ring_rst, Cp, Jm, Jnz, Jz, Hlt, Mw, - control flow 7
// Fa1, Fb1, Fc1, Fb2, Fc2, Ft2, F12 - feed a/b/c/1 into alu1, feed b/c/t/1 into alu2 7
// And, Or, Xor, Ral, Rar, Cma, Su - arithmetic and logic 7
// Ep, Emdr, Etmp, Eu, Ec, Eb, Ea - enables 7 
// Lmar, Lmdr, Lp, Li, Lt, Lc, Lb, La - loads 8


module address_ROM(
    input logic [7:0] addr, 
    output logic [7:0] data
);
    always_comb 
        case(addr) 
            8'h3c: data = 8'h03; // INR A 
            8'h04: data = 8'h04; // INR B
            8'h0c: data = 8'h05; // INR C
            8'h3d: data = 8'h06; // DCR A 
            8'h05: data = 8'h07; // DCR B
            8'h0d: data = 8'h08; // DCR C
            8'h80: data = 8'h09; // ADD B
            8'h81: data = 8'h0a; // ADD C
            8'h90: data = 8'h0b; // SUB B
            8'h91: data = 8'h0c; // SUB C 
            8'ha0: data = 8'h0d; // ANA B
            8'ha1: data = 8'h0e; // ANA C
            8'hb0: data = 8'h0f; // ORA B
            8'hb1: data = 8'h10; // ORA C
            8'ha8: data = 8'h11; // XRA B
            8'ha9: data = 8'h12; // XRA C
            8'h17: data = 8'h13; // RAL
            8'h1f: data = 8'h14; // RAR
            8'h2f: data = 8'h15; // CMA
            8'h00: data = 8'h16; // NOP
            8'h78: data = 8'h17; // MOV A, B
            8'h79: data = 8'h18; // MOV A, C
            8'h47: data = 8'h19; // MOV B, A
            8'h41: data = 8'h1a; // MOV B, C
            8'h4f: data = 8'h1b; // MOV C, A
            8'h48: data = 8'h1c; // MOV C, B
            8'h76: data = 8'h1d; // HLT
            8'h3a: data = 8'h1e; // LDA 
            8'h32: data = 8'h23; // STA
            8'h3e: data = 8'h27; // MVI A
            8'h06: data = 8'h2a; // MVI B
            8'h0e: data = 8'h2d; // MVI C 
            8'he6: data = 8'h30; // ANI 
            8'hf6: data = 8'h34; // ORI
            8'hee: data = 8'h38; // XRI
            8'hc3: data = 8'h3c; // JMP
            8'hfa: data = 8'h3f; // JM
            8'hc2: data = 8'h43; // JNZ
            8'hca: data = 8'h47; // JZ

            default: data = 8'h00;
        endcase
endmodule

module control_ROM(
    input logic [7:0] addr, 
    output logic [35:0] data
);
    always_comb    
        case(addr)
            8'h00: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // Fetch - Ep, Lmar
            8'h01: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp, increment prog_counter
            8'h02: data = 36'b0000_0000_0000_0000_0000_0010_0000_0001_0000; //       Emdr, Li
            8'h03: data = 36'b1000_0001_0000_0100_0000_0000_1000_0000_0001; // INR A - Fa1, F12, Eu, La, ring_rst
            8'h04: data = 36'b1000_0000_1000_0100_0000_0000_1000_0000_0010; // INR B - Fb1, F12, Eu, Lb, ring_rst
            8'h05: data = 36'b1000_0000_0100_0100_0000_0000_1000_0000_0100; // INR C - Fc1, F12, Eu, Lc, ring_rst
            8'h06: data = 36'b1000_0001_0000_0100_0000_1000_1000_0000_0001; // DCR A - Fa1, F12, Eu, La, ring_rst, Su
            8'h07: data = 36'b1000_0000_1000_0100_0000_1000_1000_0000_0010; // DCR B - Fb1, F12, Eu, Lb, ring_rst, Su
            8'h08: data = 36'b1000_0000_0100_0100_0000_1000_1000_0000_0100; // DCR C - Fc1, F12, Eu, Lc, ring_rst, Su

            8'h09: data = 36'b1000_0001_0010_0000_0000_0000_1000_0000_0001; // ADD B - Fa1, Fb2, Eu, La, ring_rst
            8'h0a: data = 36'b1000_0001_0001_0000_0000_0000_1000_0000_0001; // ADD C - Fa1, Fc2, Eu, La, ring_rst
            8'h0b: data = 36'b1000_0001_0010_0000_0000_1000_1000_0000_0001; // SUB B - Fa1, Fb2, Eu, La, ring_rst, Su
            8'h0c: data = 36'b1000_0001_0001_0000_0000_1000_1000_0000_0001; // SUB C - Fa1, Fc2, Eu, La, ring_rst, Su
            8'h0d: data = 36'b1000_0001_0010_0010_0000_0000_1000_0000_0001; // ANA B - Fa1, Fb2, Eu, La, ring_rst, And
            8'h0e: data = 36'b1000_0001_0001_0010_0000_0000_1000_0000_0001; // ANA C - Fa1, Fc2, Eu, La, ring_rst, And
            8'h0f: data = 36'b1000_0001_0010_0001_0000_0000_1000_0000_0001; // ORA B - Fa1, Fb2, Eu, La, ring_rst, Or
            8'h10: data = 36'b1000_0001_0001_0001_0000_0000_1000_0000_0001; // ORA C - Fa1, Fc2, Eu, La, ring_rst, Or
            8'h11: data = 36'b1000_0001_0010_0000_1000_0000_1000_0000_0001; // XRA B - Fa1, Fb2, Eu, La, ring_rst, Xor
            8'h12: data = 36'b1000_0001_0001_0000_1000_0000_1000_0000_0001; // XRA C - Fa1, Fc2, Eu, La, ring_rst, Xor
            8'h13: data = 36'b1000_0001_0000_0000_0100_0000_1000_0000_0001; // RAL - Fa1, Ral, Eu, La, ring_rst
            8'h14: data = 36'b1000_0001_0000_0000_0010_0000_1000_0000_0001; // RAR - Fa1, Rar, Eu, La, ring_rst
            8'h15: data = 36'b1000_0001_0000_0000_0001_0000_1000_0000_0001; // CMA - Fa1, Cma, Eu, La, ring_rst
            8'h16: data = 36'b1000_0000_0000_0000_0000_0000_0000_0000_0000; // NOP - ring_rst

            8'h17: data = 36'b1000_0000_0000_0000_0000_0000_0010_0000_0001; // MOV A, B - Eb, La, ring_rst 
            8'h18: data = 36'b1000_0000_0000_0000_0000_0000_0100_0000_0001; // MOV A, C - Ec, La, ring_rst 
            8'h19: data = 36'b1000_0000_0000_0000_0000_0000_0001_0000_0010; // MOV B, A - Ea, Lb, ring_rst 
            8'h1a: data = 36'b1000_0000_0000_0000_0000_0000_0100_0000_0010; // MOV B, C - Ec, Lb, ring_rst 
            8'h1b: data = 36'b1000_0000_0000_0000_0000_0000_0001_0000_0100; // MOV C, A - Ea, Lc, ring_rst 
            8'h1c: data = 36'b1000_0000_0000_0000_0000_0000_0010_0000_0100; // MOV C, B - Eb, Lc, ring_rst 
            8'h1d: data = 36'b0000_0100_0000_0000_0000_0000_0000_0000_0000; // HLT - Hlt

            8'h1e: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // LDA - Ep, Lmar
            8'h1f: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h20: data = 36'b0000_0000_0000_0000_0000_0010_0000_1000_0000; //       Emdr, Lmar; 
            8'h21: data = 36'b0000_0000_0000_0000_0000_0000_0000_0000_0000; //       NOP, wait for address to fall thru to mdr
            8'h22: data = 36'b1000_0000_0000_0000_0000_0010_0000_0000_0001; //       Emdr, La, ring_rst; 
            8'h23: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // STA - Ep, Lmar ;; we save a clock bc RAM gets data  
            8'h24: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr ;; from bus 
            8'h25: data = 36'b0000_0000_0000_0000_0000_0010_0000_1000_0000; //       Emdr, Lmar ;; rather than wait for MDR reg 
            8'h26: data = 36'b1000_0010_0000_0000_0000_0000_0001_0100_0000; //       Ea, Lmdr, Mw, ring_rst
            8'h27: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // MVI A - Ep, Lmar
            8'h28: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h29: data = 36'b1000_0000_0000_0000_0000_0010_0000_0000_0001; //       Emdr, La, ring_rst 
            8'h2a: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // MVI B - Ep, Lmar
            8'h2b: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h2c: data = 36'b1000_0000_0000_0000_0000_0010_0000_0000_0010; //       Emdr, Lb, ring_rst 
            8'h2d: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // MVI C - Ep, Lmar
            8'h2e: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h2f: data = 36'b1000_0000_0000_0000_0000_0010_0000_0000_0100; //       Emdr, Lc, ring_rst 
            8'h30: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // ANI - Ep, Lmar
            8'h31: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h32: data = 36'b0000_0000_0000_0000_0000_0010_0000_0000_1000; //       Emdr, Lt
            //                  32   28   24   20   16   12 10 8  6 4  2 0
            8'h33: data = 36'b1000_0001_0000_1010_0000_0000_1000_0000_0001; //       Fa1, Ft2, Eu, La, ring_rst, And
            8'h34: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // ORI - Ep, Lmar
            8'h35: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h36: data = 36'b0000_0000_0000_0000_0000_0010_0000_0000_1000; //       Emdr, Lt
            8'h37: data = 36'b1000_0001_0000_1001_0000_0000_1000_0000_0001; //       Fa1, Ft2, Eu, La, ring_rst, Or
            8'h38: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // XRI - Ep, Lmar
            8'h39: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h3a: data = 36'b0000_0000_0000_0000_0000_0010_0000_0000_1000; //       Emdr, Lt
            8'h3b: data = 36'b1000_0001_0000_1000_1000_0000_1000_0000_0001; //       Fa1, Ft2, Eu, La, ring_rst, Xor

            8'h3c: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; // JMP - Ep, Lmar
            8'h3d: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h3e: data = 36'b1000_0000_0000_0000_0000_0010_0000_0010_0000; //       Emdr, Lp, ring_rst 

            8'h3f: data = 36'b0010_0000_0000_0000_0000_0000_0000_0000_0000; //  JM - Jm
            8'h40: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; //       Ep, Lmar
            8'h41: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h42: data = 36'b1000_0000_0000_0000_0000_0010_0000_0010_0000; //       Emdr, Lp, ring_rst 

            8'h43: data = 36'b0001_0000_0000_0000_0000_0000_0000_0000_0000; // JNZ - Jnz
            8'h44: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; //       Ep, Lmar
            8'h45: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h46: data = 36'b1000_0000_0000_0000_0000_0010_0000_0010_0000; //       Emdr, Lp, ring_rst 

            8'h47: data = 36'b0000_1000_0000_0000_0000_0000_0000_0000_0000; //  JZ - Jz
            8'h48: data = 36'b0000_0000_0000_0000_0000_0100_0000_1000_0000; //       Ep, Lmar
            8'h49: data = 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000; //       Cp; the adress falls thru to mdr
            8'h4a: data = 36'b1000_0000_0000_0000_0000_0010_0000_0010_0000; //       Emdr, Lp, ring_rst 

            default: data = 36'b0000_0000_0000_0000_0000_0000_0000_0000_0000;
        endcase
endmodule

module SAP2(
    //output logic [3:0] led,
    input logic clk,
    input logic [3:0] btn, 
    output logic [9:0] ring_count,
    
    output logic [7:0] w_bus, prog_counter, mar, mdr, i_reg, start_address, preset_counter, t_reg, a_reg, b_reg, c_reg, ALU1, ALU2, alu, 
    output logic [1:0] flags,
    output logic [35:0] control_word
);
    //  CONTROL:  35        34  33  32   31  30   29  
    logic         ring_rst, Cp, Jm, Jnz, Jz, Hlt, Mw;
    //  ALU LOAD: 28   27   26   25   24   23   22       ALU OPS:  21   20  19   18   17   16   15
    logic         Fa1, Fb1, Fc1, Fb2, Fc2, Ft2, F12,               And, Or, Xor, Ral, Rar, Cma, Su; 
    //  ENABLES:  14  13    12    11  10  9   8            LOADS:  7     6     5   4   3   2   1   0
    logic         Ep, Emdr, Etmp, Eu, Ec, Eb, Ea,                  Lmar, Lmdr, Lp, Li, Lt, Lc, Lb, La;

    // RAM - MAR is available halfway thru T1. MDR is available halfway thru T2. i_reg is available half way thru T3. 
    logic [7:0] ram [0:2**4-1];
    initial $readmemb("C:\\Users\\pwnag\\Desktop\\prog_mem.txt", ram);
    always_ff @(posedge clk) if (Mw) ram[mar[3:0]] <= w_bus; // write operation for RAM. does not get reset (saves a clock, bypass MDR)
    
    logic CLR, ring_rst_reg;
    assign CLR = btn[3];
    always_ff @(posedge clk) // this thing is pos-pos and tells ring_count to reset next negedge (to satisfy neg-neg hold time)
        if (ring_rst | (Jz & ~flags[0]) | (Jnz & flags[0]) | (Jm & ~flags[1])) ring_rst_reg <= 1; // also reset when not jumping 
        else ring_rst_reg <= 0;
    // ring counter - "positive CLK edge occurs midway through each T state" p.147
    always_ff @(negedge clk, posedge CLR) // TODO: 10 states enough?
        if (CLR | ring_rst_reg) ring_count <= 10'b00_0000_0001; 
        else begin ring_count[0] <= ring_count[9]; for (int i = 0; i < 9; i = i + 1) ring_count[i+1] <= ring_count[i]; end

    // registers - Load: Lp, Lmar, Lmdr, Li, La, Lt, Lb, Lc 
    always_ff @(posedge clk, posedge CLR) 
        if (CLR) {prog_counter, mar, mdr, i_reg, a_reg, t_reg, b_reg, c_reg} <= 0;
        else begin 
            if (Cp | (Jz & ~flags[0]) | (Jnz & flags[0]) | (Jm & ~flags[1])) prog_counter <= prog_counter + 1; // program counter - rises halfway thru T2. also rises again during jump conditions to skip jump address
            else if (Lp) prog_counter <= w_bus; // load program counter with bus 
            if (Lmar) mar <= w_bus; 
            if (Lmdr) mdr <= w_bus; // MDR receives data from bus before write operation
            else mdr <= ram[mar[3:0]]; // read operation 
            if (Li) i_reg <= w_bus; 
            if (Lt) t_reg <= w_bus;
            if (Lc) c_reg <= w_bus;
            if (Lb) b_reg <= w_bus;
            if (La) a_reg <= w_bus;
        end 
    
    // W bus - enable for bus signals: Ep, Emdr, Etmp, Eu, Ec, Eb, Ea
    always_comb  
        case ({Ep, Emdr, Etmp, Eu, Ec, Eb, Ea})
            7'b1000000: w_bus = prog_counter; // T1 enable program counter, for mar
            7'b0100000: w_bus = mdr;
            7'b0010000: w_bus = t_reg;
            7'b0001000: w_bus = alu;
            7'b0000100: w_bus = c_reg;
            7'b0000010: w_bus = b_reg;
            7'b0000001: w_bus = a_reg;
            default: w_bus = 8'b1111_1111;
        endcase

    assign flags[0] = (alu == 0); // zero flag
    assign flags[1] = (alu > 127); // negative flag 

    // controller sequencer
    address_ROM _address_ROM(.addr(i_reg), .data(start_address)); // comb (instant)
    // presettable counter
    always_ff @(negedge clk, posedge CLR) // NEGEDGE because it's like ring_count - drives circuits in preparation for registers
        if (CLR | ring_rst_reg) preset_counter <= 0; // sets up with 0 when we're about to enter T1
        else if (preset_counter == 2) preset_counter <= start_address; // sets up with start_address when we're about to enter T4
        else preset_counter <= preset_counter + 1; // advance instruction addr by 1 during other states
    control_ROM _control_ROM(.addr(preset_counter), .data(control_word)); // comb (instant)
    assign {ring_rst, Cp, Jm, Jnz, Jz, Hlt, Mw, Fa1, Fb1, Fc1, Fb2, Fc2, Ft2, F12, And, Or, Xor, Ral, Rar, Cma, Su, Ep, Emdr, Etmp, Eu, Ec, Eb, Ea, Lmar, Lmdr, Lp, Li, Lt, Lc, Lb, La} = control_word; 

    //--------------------------------------------------------------------------------------


    // mux ALU1 (top input to ALU) - we can load either A/B/C to increment / decrement them 
    always_comb 
        case ({Fa1, Fb1, Fc1}) 
            3'b100: ALU1 = a_reg;
            3'b010: ALU1 = b_reg;
            3'b001: ALU1 = c_reg;
            default: ALU1 = a_reg; //8'b0000_0000;
        endcase

    // mux ALU2 (bottom input to ALU, which gets inverted during subtraction)
    always_comb 
        case ({Fb2, Fc2, Ft2, F12})
            4'b1000: ALU2 = b_reg;
            4'b0100: ALU2 = c_reg;
            4'b0010: ALU2 = t_reg;
            4'b0001: ALU2 = 8'b0000_0001; // for increment / decrementing 
            default: ALU2 = t_reg; //8'b0000_0000;
        endcase

    // ALU
    always_comb 
        case ({And, Or, Xor, Ral, Rar, Cma, Su})  
            7'b1000000: alu = ALU1 & ALU2;
            7'b0100000: alu = ALU1 | ALU2;
            7'b0010000: alu = ALU1 ^ ALU2;
            7'b0001000: alu = ALU1 << 1;
            7'b0000100: alu = ALU1 >> 1;
            7'b0000010: alu = ~ALU1;
            7'b0000001: alu = ALU1 - ALU2;
            default: alu = ALU1 + ALU2;
        endcase

endmodule


// we change variables around (negedge clk) so that they are constant the rest of the time, to satisfy setup & hold.
`timescale 1 ns / 1 ps 
module my_tb();
    //logic [3:0] led;
    logic clk;
    logic [3:0] btn;
    logic [9:0] ring_count;
    
    logic [7:0] w_bus, prog_counter, mar, mdr, i_reg, start_address, preset_counter, t_reg, a_reg, b_reg, c_reg, ALU1, ALU2, alu;
    logic [1:0] flags;
    logic [35:0] control_word;
    
    SAP2 uut (.*); // initialize uut    
    always begin clk = 1'b1; #(10); clk = 1'b0; #(10); end // 20 ns clock running forever 
    initial begin // other stimulus 
        // first half clock: do reset 
        btn[2:0] = 3'b000; 
        btn[3] = 1'b1; 
        @(negedge clk)
        btn[3] = 1'b0; // no more reset 
        
        repeat(30) @(negedge clk);
        $stop;
    end
endmodule

