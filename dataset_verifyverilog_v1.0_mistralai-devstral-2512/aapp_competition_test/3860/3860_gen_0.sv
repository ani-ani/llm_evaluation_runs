module badge_decks(
    input [7:0] b,
    input [7:0] g,
    input [7:0] n,
    output reg [9:0] result
);

    reg [8:0] lower_bound;
    reg [8:0] upper_bound;
    reg [8:0] diff;

    always @(*) begin
        // Calculate lower_bound = max(0, n - g)
        if (n > g) begin
            lower_bound = n - g;
        end else begin
            lower_bound = 0;
        end

        // Calculate upper_bound = min(n, b)
        if (b < n) begin
            upper_bound = b;
        end else begin
            upper_bound = n;
        end

        // Calculate diff = upper_bound - lower_bound
        diff = upper_bound - lower_bound;

        // Calculate result = max(0, diff + 1)
        if (upper_bound < lower_bound) begin
            result = 10'd0;
        end else begin
            result = diff + 10'd1;
        end
    end

endmodule