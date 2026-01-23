module check_none(
    input reg [3:0] data_0,
    input reg [3:0] data_1,
    input reg [3:0] data_2,
    input reg [3:0] data_3,
    input reg [3:0] data_4,
    output has_none
);
assign has_none = (data_0 == 4'b1111) || (data_1 == 4'b1111) || (data_2 == 4'b1111) || (data_3 == 4'b1111) || (data_4 == 4'b1111);
endmodule