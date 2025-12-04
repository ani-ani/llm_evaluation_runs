module find_min (
    input reg [7:0] numbers [0:7],
    input reg [2:0] count,
    output reg [7:0] min_num
);

    // Extended array with unused elements set to 8'hFF
    wire [7:0] extended [0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : extend_loop
            assign extended[i] = (i < count) ? numbers[i] : 8'hFF;
        end
    endgenerate

    // Comparison tree
    wire [7:0] min1_0, min1_1, min1_2, min1_3;
    assign min1_0 = (extended[0] < extended[1]) ? extended[0] : extended[1];
    assign min1_1 = (extended[2] < extended[3]) ? extended[2] : extended[3];
    assign min1_2 = (extended[4] < extended[5]) ? extended[4] : extended[5];
    assign min1_3 = (extended[6] < extended[7]) ? extended[6] : extended[7];

    wire [7:0] min2_0, min2_1;
    assign min2_0 = (min1_0 < min1_1) ? min1_0 : min1_1;
    assign min2_1 = (min1_2 < min1_3) ? min1_2 : min1_3;

    assign min_num = (min2_0 < min2_1) ? min2_0 : min2_1;

endmodule