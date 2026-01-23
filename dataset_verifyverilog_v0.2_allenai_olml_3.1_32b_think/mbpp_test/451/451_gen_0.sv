module remove_whitespaces(input [7:0][7:0] text_in, input [3:0] length_in, output [7:0][7:0] text_out, output [3:0] length_out);
reg [7:0][7:0] text_out_reg [7:0];
reg [3:0] length_out_reg;
always @(*) begin
    length_out_reg = 0;
    int i, j;
    for (i=0; i<8; i++) begin
        text_out_reg[i] = 0;
    end
    for (i=0; i<length_in; i++) begin
        if (text_in[i] != 8'b00100000) begin
            length_out_reg = length_out_reg + 1;
        end
    end
    j = 0;
    for (i=0; i<length_in; i++) begin
        if (text_in[i] != 8'b00100000) begin
            text_out_reg[j] = text_in[i];
            j = j + 1;
        end
    end
    text_out = text_out_reg;
    length_out = length_out_reg;
end
endmodule