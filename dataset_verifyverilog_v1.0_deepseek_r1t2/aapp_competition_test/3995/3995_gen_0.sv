module minimal_unique_substring #(
    parameter MAX_N = 32
)(
    input wire [4:0] n,
    input wire [4:0] k,
    output wire [MAX_N-1:0] result
);
    
    // Compute pattern parameters
    wire [4:0] a = (n - k) >> 1;
    wire [4:0] period = a + 5'd1;
    
    // Output register
    reg [MAX_N-1:0] result_reg;
    
    integer i;
    always @(*) begin
        for (i = 0; i < MAX_N; i = i + 1) begin
            if (i < n) begin
                if (a == 5'd0) begin
                    result_reg[i] = 1'b1;
                end else begin
                    result_reg[i] = ((i % period) == a) ? 1'b1 : 1'b0;
                end
            end else begin
                result_reg[i] = 1'b0;
            end
        end
    end
    
    assign result = result_reg;
    
endmodule