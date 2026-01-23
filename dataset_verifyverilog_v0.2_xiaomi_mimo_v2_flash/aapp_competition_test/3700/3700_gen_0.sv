module toy_shop(
    input [31:0] n,
    input [31:0] k,
    output reg [31:0] count
);

    // Intermediate values
    reg [31:0] min_a;
    reg [31:0] max_a;
    reg [31:0] diff;

    always @(*) begin
        // Calculate max_a = floor((k-1)/2)
        // For k >= 1, (k-1) >> 1 is equivalent to floor((k-1)/2)
        max_a = (k - 1) >> 1;

        // Calculate min_a = max(1, k-n)
        // If k-n < 1, use 1. Else use k-n.
        if (k < n + 1) begin
            min_a = 1;
        end else begin
            min_a = k - n;
        end

        // Calculate count
        // If min_a > max_a, then count is 0.
        // Else count = max_a - min_a + 1.
        if (min_a > max_a) begin
            count = 0;
        end else begin
            // Using intermediate variable to avoid overflow in calculation if needed,
            // though subtraction and addition of 32-bit values fits in 32-bit range.
            diff = max_a - min_a;
            count = diff + 1;
        end
    end

endmodule