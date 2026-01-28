module CountNumbersWith1(
    input [2:0] n,
    output [31:0] count
);
    
    // Lookup table for powers of 10 (10^(n-2) for n=2..5)
    localparam [15:0] POWER_10_0 = 16'd1;    // 10^0 = 1 (for n=2)
    localparam [15:0] POWER_10_1 = 16'd10;   // 10^1 = 10 (for n=3)
    localparam [15:0] POWER_10_2 = 16'd100;  // 10^2 = 100 (for n=4)
    localparam [15:0] POWER_10_3 = 16'd1000; // 10^3 = 1000 (for n=5)
    
    // Array to store power of 10 values
    reg [15:0] power_of_10 [0:3];
    
    // Initialize the lookup table
    always @(*) begin
        power_of_10[0] = POWER_10_0;
        power_of_10[1] = POWER_10_1;
        power_of_10[2] = POWER_10_2;
        power_of_10[3] = POWER_10_3;
    end
    
    // Compute the count
    always @(*) begin
        case (n)
            3'd0: count = 32'd0;  // Invalid case
            3'd1: count = 32'd1;  // n=1: only number 1
            3'd2: count = 18 * power_of_10[0];  // n=2: 18 * 10^0
            3'd3: count = 18 * power_of_10[1];  // n=3: 18 * 10^1
            3'd4: count = 18 * power_of_10[2];  // n=4: 18 * 10^2
            3'd5: count = 18 * power_of_10[3];  // n=5: 18 * 10^3
            default: count = 32'd0;  // Invalid case
        endcase
    end
    
endmodule