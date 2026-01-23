module max_triples(
    input [5:0] n,
    output reg [31:0] result
);

    reg [5:0] C0;
    reg [5:0] C1;

    always @(*) begin
        // Calculate C0 and C1 based on n
        if (n <= 6'd6) begin
            C0 = 6'd1;
            C1 = n - 6'd1;
        end else begin
            C0 = (n + 6'd5) / 6'd6;
            C1 = n - C0;
        end

        // Calculate combinations: C0 choose 3 and C1 choose 3
        // C0C3 = C0 * (C0 - 1) * (C0 - 2) / 6
        // C1C3 = C1 * (C1 - 1) * (C1 - 2) / 6
        // Using shifts for division by 6 (multiply by 2731/4096 approximation)
        // But since we need exact division, we'll use multiplication and division
        
        reg [31:0] C0C3;
        reg [31:0] C1C3;
        
        if (C0 >= 3) begin
            C0C3 = (C0 * (C0 - 1) * (C0 - 2)) / 6;
        end else begin
            C0C3 = 32'd0;
        end
        
        if (C1 >= 3) begin
            C1C3 = (C1 * (C1 - 1) * (C1 - 2)) / 6;
        end else begin
            C1C3 = 32'd0;
        end
        
        result = C0C3 + C1C3;
    end

endmodule