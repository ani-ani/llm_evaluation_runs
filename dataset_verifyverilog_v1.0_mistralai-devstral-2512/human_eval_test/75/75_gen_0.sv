module is_multiply_prime(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    output reg result,
    output reg done
);

    // Pre-computed LUT for products of 3 primes (1-99)
    // Valid products: 8, 12, 18, 27, 30, 42, 45, 50, 63, 70, 75, 98
    reg [99:0] lut;
    integer i;

    // Initialize LUT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset LUT and outputs
            for (i = 0; i < 100; i = i + 1) begin
                lut[i] <= 1'b0;
            end
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            // Set valid products to 1
            lut[8] <= 1'b1;
            lut[12] <= 1'b1;
            lut[18] <= 1'b1;
            lut[27] <= 1'b1;
            lut[30] <= 1'b1;
            lut[42] <= 1'b1;
            lut[45] <= 1'b1;
            lut[50] <= 1'b1;
            lut[63] <= 1'b1;
            lut[70] <= 1'b1;
            lut[75] <= 1'b1;
            lut[98] <= 1'b1;

            // Update outputs
            done <= 1'b1;
            if (a >= 8'd1 && a <= 8'd99) begin
                result <= lut[a];
            end else begin
                result <= 1'b0;
            end
        end
    end

endmodule