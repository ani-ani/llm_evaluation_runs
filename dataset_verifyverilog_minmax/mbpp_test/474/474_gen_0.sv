module char_replacer(
    input reg [127:0] str_in,
    input reg [7:0] ch,
    input reg [7:0] newch,
    output reg [127:0] str_out
);

always_comb begin
    str_out = str_in;
    for (int i = 0; i < 16; i++) begin
        if (str_in[8*i +: 8] == ch) begin
            str_out[8*i +: 8] = newch;
        end
    end
end

endmodule