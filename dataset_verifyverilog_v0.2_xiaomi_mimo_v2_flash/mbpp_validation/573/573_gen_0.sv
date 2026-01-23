module unique_product (
    input [7:0] data [0:7],
    output reg [31:0] product,
    output reg valid
);

    // Combinational logic
    integer i, j;
    reg include [0:7];
    reg [31:0] acc;
    reg overflow;
    wire [63:0] full_mul;

    always @(*) begin
        // 1. Determine uniqueness for each element
        // Element i is unique if it has not appeared in indices 0 to i-1
        for (i = 0; i < 8; i = i + 1) begin
            include[i] = 1'b1;
            for (j = 0; j < i; j = j + 1) begin
                if (data[i] == data[j]) begin
                    include[i] = 1'b0;
                end
            end
        end

        // 2. Multiply unique values and detect overflow
        acc = 32'd1;        // Start with multiplicative identity
        overflow = 1'b0;    // No overflow initially

        for (i = 0; i < 8; i = i + 1) begin
            if (include[i]) begin
                if (overflow) begin
                    // If overflow already occurred, maintain overflow flag
                    // We can keep accumulating lower 32 bits or ignore, 
                    // but flag must stay high.
                    full_mul = acc * data[i];
                    acc = full_mul[31:0];
                end else if (data[i] == 8'd0) begin
                    // Multiply by 0: result is 0, overflow cannot occur
                    acc = 32'd0;
                end else if (acc != 32'd0) begin
                    // Normal multiplication
                    full_mul = acc * data[i];
                    acc = full_mul[31:0];
                    // Check upper bits for overflow
                    if (full_mul[63:32] != 32'd0) begin
                        overflow = 1'b1;
                    end
                end
                // If acc is already 0 (due to previous zero), it stays 0
            end
        end

        product = acc;
        valid = ~overflow;
    end

endmodule