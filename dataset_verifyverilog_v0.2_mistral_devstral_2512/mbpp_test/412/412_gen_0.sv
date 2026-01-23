module remove_odd (
  input [7:0] data_in [0:7],
  input [2:0] valid_count,
  output [7:0] data_out [0:7],
  output [2:0] out_count
);

  reg [2:0] out_count_reg = 0;
  reg [7:0] data_out_reg [0:7] = '{default:0};
  integer i, j;

  always @* begin
    out_count_reg = 0;
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < valid_count && data_in[i][0] == 0) begin
        data_out_reg[j] = data_in[i];
        j = j + 1;
        out_count_reg = j;
      end
    end
  end

  assign data_out = data_out_reg;
  assign out_count = out_count_reg;

endmodule