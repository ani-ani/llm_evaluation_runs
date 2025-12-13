module element_counter(
    input  [7:0] tuple [7:0],
    input  [7:0] list  [3:0],
    output [3:0] count
);

    wire [7:0] match;

    assign match[0] = (tuple[0] == list[0]) | (tuple[0] == list[1]) | (tuple[0] == list[2]) | (tuple[0] == list[3]);
    assign match[1] = (tuple[1] == list[0]) | (tuple[1] == list[1]) | (tuple[1] == list[2]) | (tuple[1] == list[3]);
    assign match[2] = (tuple[2] == list[0]) | (tuple[2] == list[1]) | (tuple[2] == list[2]) | (tuple[2] == list[3]);
    assign match[3] = (tuple[3] == list[0]) | (tuple[3] == list[1]) | (tuple[3] == list[2]) | (tuple[3] == list[3]);
    assign match[4] = (tuple[4] == list[0]) | (tuple[4] == list[1]) | (tuple[4] == list[2]) | (tuple[4] == list[3]);
    assign match[5] = (tuple[5] == list[0]) | (tuple[5] == list[1]) | (tuple[5] == list[2]) | (tuple[5] == list[3]);
    assign match[6] = (tuple[6] == list[0]) | (tuple[6] == list[1]) | (tuple[6] == list[2]) | (tuple[6] == list[3]);
    assign match[7] = (tuple[7] == list[0]) | (tuple[7] == list[1]) | (tuple[7] == list[2]) | (tuple[7] == list[3]);

    // Popcount of 8 bits (result fits in 4 bits: 0-8)
    wire [3:0] sum0_1 = match[0] + match[1];
    wire [3:0] sum2_3 = match[2] + match[3];
    wire [3:0] sum4_5 = match[4] + match[5];
    wire [3:0] sum6_7 = match[6] + match[7];

    wire [3:0] sum0_3 = sum0_1 + sum2_3;
    wire [3:0] sum4_7 = sum4_5 + sum6_7;

    assign count = sum0_3 + sum4_7;

endmodule