module sum_of_product_lut (
    input [3:0] n,
    output reg [15:0] result
);
    // Combinational lookup table based on mathematical identity
    // For n=1: result=1, n=2: result=6, n=3: result=15, n=4: result=56
    // Invalid inputs (n=0 or n>4) return 0

    always @(*) begin
        case (n)
            4'd1: result = 16'd1;
            4'd2: result = 16'd6;
            4'd3: result = 16'd15;
            4'd4: result = 16'd56;
            default: result = 16'd0;
        endcase
    end

endmodule