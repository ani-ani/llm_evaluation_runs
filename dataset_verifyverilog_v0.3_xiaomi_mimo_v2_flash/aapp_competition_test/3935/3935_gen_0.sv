module TopModule (
    input wire [3:0] number,
    output reg [6:0] segments
);
    always @(*) begin
        case (number)
            4'd0: segments = 7'b0111111; // a,b,c,d,e,f
            4'd1: segments = 7'b0000110; // b,c
            4'd2: segments = 7'b1011011; // a,b,d,e,g
            4'd3: segments = 7'b1001111; // a,b,c,d,g
            4'd4: segments = 7'b1100110; // b,c,f,g
            4'd5: segments = 7'b1101101; // a,c,d,f,g
            4'd6: segments = 7'b1111101; // a,c,d,e,f,g
            4'd7: segments = 7'b0000111; // a,b,c
            4'd8: segments = 7'b1111111; // a,b,c,d,e,f,g
            4'd9: segments = 7'b1101111; // a,b,c,d,f,g
            4'd10: segments = 7'b1110111; // a,b,c,e,f,g (A)
            4'd11: segments = 7'b1111100; // c,d,e,f,g (b)
            4'd12: segments = 7'b0111001; // a,d,e,f (C)
            4'd13: segments = 7'b1011110; // a,b,c,d,e,g (d)
            4'd14: segments = 7'b1111001; // a,d,e,f,g (E)
            4'd15: segments = 7'b1110001; // a,e,f,g (F)
            default: segments = 7'b0000000;
        endcase
    end
endmodule