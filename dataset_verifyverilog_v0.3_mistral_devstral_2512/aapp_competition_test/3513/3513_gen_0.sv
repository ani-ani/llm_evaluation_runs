module max_factors_power2 (
    input wire [63:0] X,
    output reg [4:0] k
);

    reg [5:0] n; // N is between 0 and 63
    integer i;
    integer j;
    reg [4:0] k_reg;

    always @(*) begin
        n = 6'd0;
        // Priority encoder: find highest set bit
        for (i = 63; i >= 0; i = i - 1) begin
            if (X[i]) begin
                n = i;
                i = -1; // Exit loop
            end
        end
    end

    always @(*) begin
        k_reg = 5'd0;
        for (j = 1; j <= 10; j = j + 1) begin
            if (j * (j + 1) / 2 <= n) begin
                k_reg = j;
            end else begin
                j = 11; // Exit loop
            end
        end
    end

    assign k = k_reg;

endmodule