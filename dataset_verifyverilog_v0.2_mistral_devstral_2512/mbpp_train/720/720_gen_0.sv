module add_dict_to_tuple (
    input [7:0] tuple_data [0:2],
    input [2:0] tuple_len,
    input [7:0] dict_keys [0:2],
    input [7:0] dict_vals [0:2],
    input [2:0] dict_len,
    output reg [63:0] result
);
    integer i, j;
    always @(*) begin
        result = 64'b0;
        for (i = 0; i < tuple_len; i = i + 1) begin
            result[(i * 8) +: 8] = tuple_data[i];
        end
        for (j = 0; j < dict_len; j = j + 1) begin
            result[(tuple_len * 8) + (j * 8) +: 8] = dict_vals[j];
        end
    end
endmodule