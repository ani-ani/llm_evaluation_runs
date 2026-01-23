module minimal_unique_substring #(
    parameter MAX_N = 32
)(
    input wire [4:0] n,      // String length (1 to MAX_N)
    input wire [4:0] k,      // Desired minimal unique substring length
    output wire [MAX_N-1:0] result // Generated string, bit 0 = first character
);

    // Compute pattern parameters
    wire [4:0] a = (n - k) >> 1;      // Number of zeros before each '1'
    wire [4:0] period = a + 1;        // Pattern period length
    
    // Combinational logic to generate output bits
    reg [MAX_N-1:0] result_reg;
    
    integer i;
    always @(*) begin
        for (i = 0; i < MAX_N; i = i + 1) begin
            if (i < n) begin
                if (a == 5'd0) begin
                    // Case: n == k, all bits are 1
                    result_reg[i] = 1'b1;
                end else begin
                    // Pattern: positions that are multiples of period minus 1 get '1'
                    result_reg[i] = ((i % period) == a) ? 1'b1 : 1'b0;
                end
            end else begin
                // Unused positions (i >= n) are set to 0
                result_reg[i] = 1'b0;
            end
        end
    end
    
    assign result = result_reg;

endmodule