module find_max (
    input [7:0] data_in [0:7],
    output [7:0] max_value
);

    // Level 1: Compare 8 inputs into 4 winners
    wire [7:0] l1_w0 = (data_in[0] > data_in[1]) ? data_in[0] : data_in[1];
    wire [7:0] l1_w1 = (data_in[2] > data_in[3]) ? data_in[2] : data_in[3];
    wire [7:0] l1_w2 = (data_in[4] > data_in[5]) ? data_in[4] : data_in[5];
    wire [7:0] l1_w3 = (data_in[6] > data_in[7]) ? data_in[6] : data_in[7];

    // Level 2: Compare 4 winners into 2
    wire [7:0] l2_w0 = (l1_w0 > l1_w1) ? l1_w0 : l1_w1;
    wire [7:0] l2_w1 = (l1_w2 > l1_w3) ? l1_w2 : l1_w3;

    // Level 3: Compare 2 winners into 1
    assign max_value = (l2_w0 > l2_w1) ? l2_w0 : l2_w1;

endmodule