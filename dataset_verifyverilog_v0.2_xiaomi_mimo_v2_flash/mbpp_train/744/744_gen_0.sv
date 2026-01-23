module check_none (
    input [3:0] data_0,
    input [3:0] data_1,
    input [3:0] data_2,
    input [3:0] data_3,
    input [3:0] data_4,
    output has_none
);

    assign has_none = (data_0 == 4'hF) || (data_1 == 4'hF) || (data_2 == 4'hF) || (data_3 == 4'hF) || (data_4 == 4'hF);

endmodule