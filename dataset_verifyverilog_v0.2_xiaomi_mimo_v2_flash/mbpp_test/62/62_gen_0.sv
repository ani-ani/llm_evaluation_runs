module find_min (
    input [7:0] data_in [0:7],
    output [7:0] min_value
);

    // Stage 1: 8 inputs -> 4 outputs
    wire [7:0] stage1 [0:3];
    assign stage1[0] = (data_in[0] < data_in[1]) ? data_in[0] : data_in[1];
    assign stage1[1] = (data_in[2] < data_in[3]) ? data_in[2] : data_in[3];
    assign stage1[2] = (data_in[4] < data_in[5]) ? data_in[4] : data_in[5];
    assign stage1[3] = (data_in[6] < data_in[7]) ? data_in[6] : data_in[7];

    // Stage 2: 4 inputs -> 2 outputs
    wire [7:0] stage2 [0:1];
    assign stage2[0] = (stage1[0] < stage1[1]) ? stage1[0] : stage1[1];
    assign stage2[1] = (stage1[2] < stage1[3]) ? stage1[2] : stage1[3];

    // Stage 3: 2 inputs -> 1 output
    assign min_value = (stage2[0] < stage2[1]) ? stage2[0] : stage2[1];

endmodule