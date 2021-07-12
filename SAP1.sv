module address_ROM(
    input logic [3:0] addr, 
    output logic [3:0] data
);
    always_comb 
        case(addr)
            4'b0000: data = 4'b0011; // LDA
            4'b0001: data = 4'b0110; // ADD
            4'b0010: data = 4'b1001; // SUB
            4'b1110: data = 4'b1100; // OUT
            default: data = 4'b0000;
        endcase
endmodule

module program_ROM(
    input logic [3:0] addr, 
    output logic [7:0] data
);
    always_comb 
        case(addr)
            4'h0: data = 8'b0000_1010; // lda A
            4'h1: data = 8'b0001_1011; // add B
            4'h2: data = 8'b0010_1100; // sub C 
            4'h3: data = 8'b1110_0000; // out
            4'h4: data = 8'b1111_0000; // hlt
            4'h5: data = 8'b0000_0000;
            4'h6: data = 8'b0000_0000;
            4'h7: data = 8'b0000_0000;
            4'h8: data = 8'b0000_0000;
            4'h9: data = 8'b0000_0000;
            4'ha: data = 8'b0000_0001;
            4'hb: data = 8'b0000_0001;
            4'hc: data = 8'b0000_0001;
            4'hd: data = 8'b0000_0000;
            4'he: data = 8'b0000_0000;
            4'hf: data = 8'b0000_0000;
        endcase
endmodule

module control_ROM(
    input logic [3:0] addr, 
    output logic [11:0] data
);
    always_comb    
        case(addr) // Lo, Lb, La, Su, Ea, Eu, Cp, Ep, Lm, CE, Li, Ei,
            4'h0: data = 12'b0000_0001_1000; // fetch 
            4'h1: data = 12'b0000_0010_0000;
            4'h2: data = 12'b0000_0000_0110;
            4'h3: data = 12'b0000_0000_1001; // LDA
            4'h4: data = 12'b0010_0000_0100;
            4'h5: data = 12'b0000_0000_0000;
            4'h6: data = 12'b0000_0000_1001; // ADD 
            4'h7: data = 12'b0100_0000_0100;
            4'h8: data = 12'b0010_0100_0000;
            4'h9: data = 12'b0000_0000_1001; // SUB
            4'ha: data = 12'b0100_0000_0100;
            4'hb: data = 12'b0011_0100_0000;
            4'hc: data = 12'b1000_1000_0000; // OUT 
            4'hd: data = 12'b0000_0000_0000;
            4'he: data = 12'b0000_0000_0000;
            4'hf: data = 12'b0000_0000_0000;
        endcase
endmodule

module SAP1_v1(
    input logic clk,
    input logic [3:0] btn, 
    //output logic [3:0] led,
    output logic [5:0] ring_count,
    output logic [7:0] ram_out, i_reg, w_bus, alu, a_reg, b_reg, out_reg, 
    output logic [3:0] mar, prog_counter, start_address, preset_counter,
    output logic [11:0] control_word
);
    logic Lo, Lb, La, Su, Ea, Eu, Cp, Ep, Lm, CE, Li, Ei, CLR;
    assign CLR = btn[3];

    // ring counter - "positive CLK edge occurs midway through each T state" p.147
    always_ff @(negedge clk, posedge CLR) 
        if (CLR)
            ring_count <= 6'b100000;
        else begin 
            ring_count[0] <= ring_count[5];
            for (int i = 0; i < 5; i = i + 1)  
                ring_count[i+1] <= ring_count[i];
        end

    // RAM 
    program_ROM _program_ROM(.addr(mar), .data(ram_out)); // comb (instant)

    // controller sequencer
    address_ROM _address_ROM(.addr(i_reg[7:4]), .data(start_address)); // comb (instant)
    // presettable counter
    always_ff @(negedge clk, posedge CLR) // NEGEDGE because it's like ring_count - drives circuits in preparation for registers
        if (CLR || (ring_count == 6'b100_000)) // sets up with 0 when we're about to enter T1
            preset_counter <= 0;
        else if (ring_count == 6'b000_100) // sets up with start_address when we're about to enter T4
            preset_counter <= start_address;
        else 
            preset_counter <= preset_counter + 1; // advance instruction addr by 1 during other states
    control_ROM _control_ROM(.addr(preset_counter), .data(control_word)); // comb (instant)
    assign {Lo, Lb, La, Su, Ea, Eu, Cp, Ep, Lm, CE, Li, Ei} = control_word;

    //------------------------------------------------------------------------------------------------


    // a, b, out register 
    always_ff @(posedge clk, posedge CLR) 
        if (CLR) begin 
            prog_counter <= 0;
            mar <= 0; 
            i_reg <= 0; 
            a_reg <= 0;
            b_reg <= 0;
            out_reg <= 0;
        end 
        else begin 
            if (Cp) prog_counter <= prog_counter + 1; // program counter - rises halfway thru T2
            if (Lm) mar <= w_bus[3:0]; 
            if (Li) i_reg <= w_bus; // instruction reg
            if (La) a_reg <= w_bus;
            if (Lb) b_reg <= w_bus;
            if (Lo) out_reg <= w_bus;
        end 
    // adder / subtractor
    assign alu = Su ? (a_reg - b_reg) : (a_reg + b_reg);
    
    // W bus
    always_comb 
        case ({Ea, Eu, Ep, CE, Ei})
            5'b10000: w_bus = a_reg; // enable register A on the bus
            5'b01000: w_bus = alu; // enable the ALU 
            5'b00100: w_bus = {{4{1'b0}}, prog_counter}; // T1 enable program counter, for mar
            5'b00010: w_bus = ram_out; // T3 enable RAM, for i_reg 
            5'b00001: w_bus = {{4{1'b0}}, i_reg[3:0]}; // enable instruction register 
            default: w_bus = 8'b1111_1111;
        endcase

endmodule

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


/*
0 0000 1010     LDA *A ; which is 1 at address A 
1 0001 1011     ADD *B ; add 1 which is at B
2 0010 1100     SUB *C ; sub 1 which is at C
3 1110 0000     OUT    ; display result in OUT 
4 1111 0000     HLT    ; uhh
5
6
7
8
9
A 0000 0001
B 0000 0001
C 0000 0001
D
E
F
*/

// Cp, Su, 
// Ei, Ea, Eu, Ep, CE
// Li, La, Lb, Lo, Lm
