module polyline_solver (
    input [31:0] a,
    input [31:0] b,
    output reg valid,
    output reg [31:0] num,
    output reg [31:0] den
);

    // Internal signals for computation
    reg [31:0] a_reg;
    reg [31:0] b_reg;
    reg [31:0] a_minus_b;
    reg [63:0] temp_product;  // For 32-bit multiplication
    reg [31:0] k_max;
    reg [31:0] k_max_plus_1;
    reg [31:0] two_b;
    reg [31:0] den_temp;
    reg [31:0] num_temp;
    reg valid_temp;
    
    // Combinational logic
    always @(*) begin
        // Initialize all values
        valid_temp = 1'b0;
        num_temp = 32'd0;
        den_temp = 32'd0;
        a_minus_b = 32'd0;
        k_max = 32'd0;
        k_max_plus_1 = 32'd0;
        two_b = 32'd0;
        
        // Check condition a >= b
        if (a >= b) begin
            valid_temp = 1'b1;
            
            // Compute a - b
            a_minus_b = a - b;
            
            // Compute 2 * b
            two_b = b << 1;  // Equivalent to 2 * b
            
            // Compute k_max = (a - b) / (2 * b)
            // Use 64-bit intermediate to prevent overflow
            // If two_b is 0 (shouldn't happen for b >= 1), handle safely
            if (two_b == 32'd0) begin
                k_max = 32'd0;
            end else begin
                k_max = a_minus_b / two_b;
            end
            
            // Compute k_max + 1
            k_max_plus_1 = k_max + 32'd1;
            
            // Compute den = 2 * (k_max + 1)
            den_temp = k_max_plus_1 << 1;  // Multiply by 2
            
            // Compute num = a + b
            num_temp = a + b;
            
            // Assign outputs
            num = num_temp;
            den = den_temp;
            valid = valid_temp;
        end else begin
            // a < b: valid = 0, outputs are don't-care
            num = 32'd0;
            den = 32'd0;
            valid = 1'b0;
        end
    end

endmodule