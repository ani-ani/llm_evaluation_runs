module TetrahedralNumber (
    input wire [7:0] n,
    output reg signed [15:0] result
);
    // Intermediate signals
    wire [31:0] prod;
    wire [31:0] div_result;
    wire [31:0] n_plus_1;
    wire [31:0] n_plus_2;
    wire [31:0] n_extended;
    
    // Extend n to 32 bits for calculation
    assign n_extended = {24'd0, n};
    assign n_plus_1 = n_extended + 32'd1;
    assign n_plus_2 = n_extended + 32'd2;
    
    // Calculate product: n * (n + 1) * (n + 2)
    // Use 32-bit multiplication to prevent overflow
    assign prod = n_extended * n_plus_1 * n_plus_2;
    
    // Divide by 6 (integer division)
    // Since the formula yields integer, truncation is correct
    assign div_result = prod / 32'd6;
    
    // Saturate to 16-bit signed range (-32768 to 32767)
    always @(*) begin
        if (div_result > 32'd32767) begin
            result = 16'sd32767;
        end else begin
            result = $signed(div_result[15:0]);
        end
    end
endmodule