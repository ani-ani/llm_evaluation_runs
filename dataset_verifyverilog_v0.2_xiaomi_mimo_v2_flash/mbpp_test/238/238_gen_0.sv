module substring_counter (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output reg [7:0] result
);

    // Combinational logic block
    always @(*) begin
        // Determine string length n
        // Count non-zero bytes from start, stop at first zero
        reg [3:0] n;
        n = 4'd0;
        
        if (char_0 != 8'h00) begin
            n = 4'd1;
            if (char_1 != 8'h00) begin
                n = 4'd2;
                if (char_2 != 8'h00) begin
                    n = 4'd3;
                    if (char_3 != 8'h00) begin
                        n = 4'd4;
                        if (char_4 != 8'h00) begin
                            n = 4'd5;
                            if (char_5 != 8'h00) begin
                                n = 4'd6;
                                if (char_6 != 8'h00) begin
                                    n = 4'd7;
                                    if (char_7 != 8'h00) begin
                                        n = 4'd8;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        // Compute result = n * (n + 1) / 2 using lookup table
        case (n)
            4'd0: result = 8'd0;   // 0*(0+1)/2 = 0
            4'd1: result = 8'd1;   // 1*(1+1)/2 = 1
            4'd2: result = 8'd3;   // 2*(2+1)/2 = 3
            4'd3: result = 8'd6;   // 3*(3+1)/2 = 6
            4'd4: result = 8'd10;  // 4*(4+1)/2 = 10
            4'd5: result = 8'd15;  // 5*(5+1)/2 = 15
            4'd6: result = 8'd21;  // 6*(6+1)/2 = 21
            4'd7: result = 8'd28;  // 7*(7+1)/2 = 28
            4'd8: result = 8'd36;  // 8*(8+1)/2 = 36
            default: result = 8'd0; // Should not occur
        endcase
    end

endmodule
