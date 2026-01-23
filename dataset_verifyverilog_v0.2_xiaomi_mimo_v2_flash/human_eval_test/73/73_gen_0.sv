module smallest_change(
    input [3:0] arr [0:7],
    output [3:0] changes
);

    wire [3:0] mismatch;

    // Compare each mirrored pair
    assign mismatch[0] = (arr[0] != arr[7]);
    assign mismatch[1] = (arr[1] != arr[6]);
    assign mismatch[2] = (arr[2] != arr[5]);
    assign mismatch[3] = (arr[3] != arr[4]);

    // Sum all mismatches
    assign changes = mismatch[0] + mismatch[1] + mismatch[2] + mismatch[3];

endmodule