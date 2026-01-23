module odd_Equivalent(
    input [7:0] binary_string,
    output reg [3:0] count
);
    // Combinational logic for counting 1 bits using parallel reduction
    // Uses a tree structure: 4x2bit adders -> 2x3bit adder -> 1x4bit output
    
    wire [1:0] count_0_1;     // Count of bits 0 and 1
    wire [1:0] count_2_3;     // Count of bits 2 and 3
    wire [1:0] count_4_5;     // Count of bits 4 and 5
    wire [1:0] count_6_7;     // Count of bits 6 and 7
    
    wire [2:0] count_low;     // Lower half total (bits 0-3)
    wire [2:0] count_high;    // Upper half total (bits 4-7)
    wire [2:0] total_temp;    // 3-bit intermediate sum
    
    // Level 1: Each pair of bits adds to a 2-bit sum
    assign count_0_1 = binary_string[0] + binary_string[1];
    assign count_2_3 = binary_string[2] + binary_string[3];
    assign count_4_5 = binary_string[4] + binary_string[5];
    assign count_6_7 = binary_string[6] + binary_string[7];
    
    // Level 2: Add pairs to get 3-bit sums (max 4)
    assign count_low = count_0_1 + count_2_3;
    assign count_high = count_4_5 + count_6_7;
    
    // Level 3: Final 4-bit output (max 8)
    // Wire directly to output reg
    assign total_temp = count_low + count_high;
    
    always @(*) begin
        count = {1'b0, total_temp};  // Zero-extend 3-bit to 4-bit
    end
    
endmodule