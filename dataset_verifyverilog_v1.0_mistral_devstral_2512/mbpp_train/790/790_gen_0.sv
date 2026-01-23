module even_position_check (
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [2:0] len,
    output wire result
);

    wire element_parity_0 = arr_0[0];
    wire element_parity_1 = arr_1[0];
    wire element_parity_2 = arr_2[0];

    wire check_0 = (element_parity_0 == 1'b0);
    wire check_1 = (element_parity_1 == 1'b1);
    wire check_2 = (element_parity_2 == 1'b0);

    assign result = (
        ((len >= 3'd1) && check_0) &&
        ((len >= 3'd2) && check_1) &&
        ((len >= 3'd3) && check_2)
    );

endmodule