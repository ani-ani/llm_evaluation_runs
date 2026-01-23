module odd_length_sum (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [2:0] length,
    output [31:0] result
);

    // Internal wires to store weighted results for each index
    wire [31:0] weight_0;
    wire [31:0] weight_1;
    wire [31:0] weight_2;
    wire [31:0] weight_3;
    wire [31:0] weight_4;
    wire [31:0] weight_5;
    wire [31:0] weight_6;
    wire [31:0] weight_7;

    // Calculate contribution for each index based on length
    // Formula: ((i+1)*(l-i) + 1) / 2
    // The division by 2 is handled by integer division in Verilog
    // Logic: if length > i, calculate contribution, else 0

    // Index 0: i=0, (1*(length-0) + 1)/2
    assign weight_0 = (length > 0) ? ((1 * (length - 0) + 1) >> 1) * arr_0 : 0;

    // Index 1: i=1, (2*(length-1) + 1)/2
    assign weight_1 = (length > 1) ? ((2 * (length - 1) + 1) >> 1) * arr_1 : 0;

    // Index 2: i=2, (3*(length-2) + 1)/2
    assign weight_2 = (length > 2) ? ((3 * (length - 2) + 1) >> 1) * arr_2 : 0;

    // Index 3: i=3, (4*(length-3) + 1)/2
    assign weight_3 = (length > 3) ? ((4 * (length - 3) + 1) >> 1) * arr_3 : 0;

    // Index 4: i=4, (5*(length-4) + 1)/2
    assign weight_4 = (length > 4) ? ((5 * (length - 4) + 1) >> 1) * arr_4 : 0;

    // Index 5: i=5, (6*(length-5) + 1)/2
    assign weight_5 = (length > 5) ? ((6 * (length - 5) + 1) >> 1) * arr_5 : 0;

    // Index 6: i=6, (7*(length-6) + 1)/2
    assign weight_6 = (length > 6) ? ((7 * (length - 6) + 1) >> 1) * arr_6 : 0;

    // Index 7: i=7, (8*(length-7) + 1)/2
    assign weight_7 = (length > 7) ? ((8 * (length - 7) + 1) >> 1) * arr_7 : 0;

    // Sum all weighted elements
    assign result = weight_0 + weight_1 + weight_2 + weight_3 + 
                    weight_4 + weight_5 + weight_6 + weight_7;

endmodule