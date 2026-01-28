module prime_length(
    input [127:0] string_data,
    input [3:0] string_len,
    output reg result
);
    // Combinational logic to determine if length is prime
    always @(*) begin
        case (string_len)
            4'd0, 4'd1, 4'd4, 4'd6, 4'd8, 4'd9, 4'd10, 4'd12, 4'd14, 4'd15, 4'd16: result = 1'b0;
            4'd2, 4'd3, 4'd5, 4'd7, 4'd11, 4'd13: result = 1'b1;
            default: result = 1'b0; // Covers any other values (shouldn't occur)
        endcase
    end
endmodule