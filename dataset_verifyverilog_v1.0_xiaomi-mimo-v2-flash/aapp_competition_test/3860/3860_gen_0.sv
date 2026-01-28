module BadgeDecks(
    input [7:0] b,
    input [7:0] g,
    input [7:0] n,
    output reg [15:0] result
);

    // Intermediate calculations (using 16 bits for safety)
    reg [15:0] n_minus_g;
    reg [15:0] lower_bound;
    reg [15:0] upper_bound;
    reg [15:0] diff;
    reg [15:0] temp_result;

    always @(*) begin
        // Calculate n - g as signed to handle negative values
        // Since inputs are unsigned, we cast to signed logic
        if (n > g) begin
            n_minus_g = n - g;  // Unsigned subtraction (safe since n > g)
        end else begin
            n_minus_g = 16'd0;   // Clamp to 0 if negative
        end

        // Lower bound: max(0, n - g)
        lower_bound = n_minus_g;

        // Upper bound: min(n, b)
        if (b < n) begin
            upper_bound = b;
        end else begin
            upper_bound = n;
        end

        // Calculate count: max(0, upper_bound - lower_bound + 1)
        if (upper_bound < lower_bound) begin
            temp_result = 16'd0;
        end else begin
            diff = upper_bound - lower_bound;
            temp_result = diff + 16'd1;
        end

        // Assign to output (16-bit, which satisfies 10-bit requirement)
        result = temp_result;
    end

endmodule