module unique_product(
    input [7:0] data [0:7],
    output reg [31:0] product,
    output reg valid
);

    integer i, j;
    reg [31:0] acc;
    reg overflow;
    reg include [0:7];
    wire [63:0] full_mul;

    always @(*) begin
        // Initialize
        acc = 32'd1;
        overflow = 1'b0;
        product = 32'd0;
        valid = 1'b0;

        // Determine uniqueness for each element
        for (i = 0; i < 8; i = i + 1) begin
            include[i] = 1'b1;
            for (j = 0; j < i; j = j + 1) begin
                if (data[i] == data[j]) begin
                    include[i] = 1'b0;
                end
            end
        end

        // Multiply unique values
        for (i = 0; i < 8; i = i + 1) begin
            if (include[i]) begin
                if (data[i] == 8'd0) begin
                    acc = 32'd0;
                end else if (acc != 32'd0) begin
                    full_mul = acc * data[i];
                    if (full_mul[63:32] != 32'd0) begin
                        overflow = 1'b1;
                    end
                    acc = full_mul[31:0];
                end
            end
        end

        product = acc;
        valid = ~overflow;
    end

endmodule