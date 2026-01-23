module tuple_contains_k (
    input [7:0] k,
    input [7:0] data [0:7],
    output found
);

    wire [7:0] match;

    assign match[0] = (k == data[0]);
    assign match[1] = (k == data[1]);
    assign match[2] = (k == data[2]);
    assign match[3] = (k == data[3]);
    assign match[4] = (k == data[4]);
    assign match[5] = (k == data[5]);
    assign match[6] = (k == data[6]);
    assign match[7] = (k == data[7]);

    assign found = |match;

endmodule