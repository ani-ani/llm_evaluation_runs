module sum_of_product_lut(
    input [3:0] n,
    output [15:0] result
);

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