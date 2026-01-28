module count_n_digit_numbers (
    input [2:0] n,
    output reg [31:0] count
);

    // Lookup table for 10^(n-2) for n=2,3,4,5
    // Index 0: n=2 -> 10^0 = 1
    // Index 1: n=3 -> 10^1 = 10
    // Index 2: n=4 -> 10^2 = 100
    // Index 3: n=5 -> 10^3 = 1000
    reg [31:0] power_of_10 [0:3];

    // Initialize LUT
    initial begin
        power_of_10[0] = 32'd1;
        power_of_10[1] = 32'd10;
        power_of_10[2] = 32'd100;
        power_of_10[3] = 32'd1000;
    end

    // Combinational logic for computation
    always @(*) begin
        case (n)
            3'd1: count = 32'd1;  // Single digit: only number 1
            3'd2: count = 32'd18 * power_of_10[0];  // 18 * 1 = 18
            3'd3: count = 32'd18 * power_of_10[1];  // 18 * 10 = 180
            3'd4: count = 32'd18 * power_of_10[2];  // 18 * 100 = 1800
            3'd5: count = 32'd18 * power_of_10[3];  // 18 * 1000 = 18000
            default: count = 32'd0;  // Invalid input (n=0 or >5)
        endcase
    end

endmodule