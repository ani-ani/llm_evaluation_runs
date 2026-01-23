module is_product_even(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output result
);

    wire [7:0] even_flags;

    assign even_flags[0] = (len >= 4'd1) ? ~arr_0[0] : 1'b0;
    assign even_flags[1] = (len >= 4'd2) ? ~arr_1[0] : 1'b0;
    assign even_flags[2] = (len >= 4'd3) ? ~arr_2[0] : 1'b0;
    assign even_flags[3] = (len >= 4'd4) ? ~arr_3[0] : 1'b0;
    assign even_flags[4] = (len >= 4'd5) ? ~arr_4[0] : 1'b0;
    assign even_flags[5] = (len >= 4'd6) ? ~arr_5[0] : 1'b0;
    assign even_flags[6] = (len >= 4'd7) ? ~arr_6[0] : 1'b0;
    assign even_flags[7] = (len >= 4'd8) ? ~arr_7[0] : 1'b0;

    assign result = |even_flags;

endmodule