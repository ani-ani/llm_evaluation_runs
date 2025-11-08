module lfsr_5bit_galois (
    input clk,
    input reset,
    output reg [4:0] q
);

    // Taps at bit positions 5 and 3 (assuming 1-based indexing)
    // This corresponds to q[4] and q[2] in 0-based indexing

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q <= 5'b10000; // Initial seed value
        end else begin
            // Right shift operation
            q[0] <= q[1];
            q[1] <= q[2];
            q[2] <= q[3] ^ q[0]; // Tap at position 3 (q[2])
            q[3] <= q[4];
            q[4] <= q[0]; // Tap at position 5 (q[4])
        end
    end

endmodule