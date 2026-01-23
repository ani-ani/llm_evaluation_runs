module char_counter (
    input [63:0] str_data,
    input [2:0] str_length,
    output [3:0] char_count
);

    assign char_count = {1'b0, str_length};

endmodule