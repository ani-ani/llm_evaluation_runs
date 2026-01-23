module parity_calculator (
    input  [31:0] num,      // 32-bit input number
    output        parity    // 1 if odd parity (odd number of 1s), 0 if even parity
);

    // Combinational logic to compute parity using XOR reduction tree
    // This implements the algorithm: y = x ^ (x>>1) ^ (x>>2) ^ (x>>4) ... then check LSB
    
    wire [31:0] stage1;
    wire [31:0] stage2;
    wire [31:0] stage3;
    wire [31:0] stage4;
    wire [31:0] stage5;
    
    assign stage1 = num ^ (num >> 1);
    assign stage2 = stage1 ^ (stage1 >> 2);
    assign stage3 = stage2 ^ (stage2 >> 4);
    assign stage4 = stage3 ^ (stage3 >> 8);
    assign stage5 = stage4 ^ (stage4 >> 16);
    
    // The LSB of the final result contains the parity
    // 1 = odd number of 1s (odd parity)
    // 0 = even number of 1s (even parity)
    assign parity = stage5[0];

endmodule