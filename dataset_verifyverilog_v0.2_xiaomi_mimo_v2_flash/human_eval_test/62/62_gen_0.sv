module poly_derivative (
    input [2:0] num_coeffs,
    input [15:0] xs [0:7],
    output reg [15:0] deriv [0:6],
    output reg [2:0] deriv_len
);

    integer i;

    always @(*) begin
        // Default assignment to avoid latches
        deriv_len = 3'd0;
        for (int j = 0; j < 7; j++) begin
            deriv[j] = 16'sd0;
        end

        if (num_coeffs > 3'd1) begin
            deriv_len = num_coeffs - 3'd1;
            for (i = 0; i < 7; i = i + 1) begin
                if (i < deriv_len) begin
                    deriv[i] = xs[i+1] * (i + 1);
                end
            end
        end
    end

endmodule