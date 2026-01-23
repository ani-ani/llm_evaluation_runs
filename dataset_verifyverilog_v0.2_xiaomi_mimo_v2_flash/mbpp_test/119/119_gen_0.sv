module find_unique (
    input [7:0] arr [0:7],
    output [7:0] unique_val
);

    assign unique_val = arr[0] ^ arr[1] ^ arr[2] ^ arr[3] ^ arr[4] ^ arr[5] ^ arr[6] ^ arr[7];

endmodule