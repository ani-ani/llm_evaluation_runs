module decimal_to_binary_converter(
    input [15:0] decimal_in,
    output [15:0] binary_out,
    output [4:0] significant_bits
);

    assign binary_out = decimal_in;

    always_comb begin
        casez (decimal_in)
            16'b1???????????????: significant_bits = 5'd16;
            16'b01??????????????: significant_bits = 5'd15;
            16'b001?????????????: significant_bits = 5'd14;
            16'b0001????????????: significant_bits = 5'd13;
            16'b00001???????????: significant_bits = 5'd12;
            16'b000001??????????: significant_bits = 5'd11;
            16'b0000001?????????: significant_bits = 5'd10;
            16'b00000001????????: significant_bits = 5'd9;
            16'b000000001???????: significant_bits = 5'd8;
            16'b0000000001??????: significant_bits = 5'd7;
            16'b00000000001?????: significant_bits = 5'd6;
            16'b000000000001????: significant_bits = 5'd5;
            16'b0000000000001???: significant_bits = 5'd4;
            16'b00000000000001??: significant_bits = 5'd3;
            16'b000000000000001?: significant_bits = 5'd2;
            16'b0000000000000001: significant_bits = 5'd1;
            default: significant_bits = 5'd1;
        endcase
    end

endmodule