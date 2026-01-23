module remove_whitespaces (
  input [7:0][7:0] text_in,
  input [3:0] length_in,
  output [7:0][7:0] text_out,
  output [3:0] length_out
);

  reg [7:0][7:0] text_out_reg;
  reg [3:0] length_out_reg;
  integer i, j;

  always @* begin
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < length_in && text_in[i] != 8'h20) begin
        text_out_reg[j] = text_in[i];
        j = j + 1;
      end
    end
    length_out_reg = j;
  end

  assign text_out = text_out_reg;
  assign length_out = length_out_reg;

endmodule