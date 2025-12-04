module remove_odd_chars (
    input reg [7:0] str_in [0:7],
    output reg [7:0] str_out [0:3],
    output reg [2:0] out_len
);

    wire [3:0] temp_count = (str_in[0] != 0) + (str_in[1] != 0) + (str_in[2] != 0) + (str_in[3] != 0) +
                        (str_in[4] != 0) + (str_in[5] != 0) + (str_in[6] != 0) + (str_in[7] != 0);

    assign out_len = temp_count / 2;

    assign str_out = '{ str_in[1], str_in[3], str_in[5], str_in[7] };

endmodule