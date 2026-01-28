module sum_even_check(
    input [7:0] n,
    output reg result
);

    always @(*) begin
        if (n[0] == 1'b0) begin  // Check if n is even
            if (n >= 8'd8) begin  // Check if n >= 8
                if (n != 8'd10) begin  // Check if n != 10
                    result = 1'b1;
                end else begin
                    result = 1'b0;
                end
            end else begin
                result = 1'b0;
            end
        end else begin
            result = 1'b0;
        end
    end

endmodule