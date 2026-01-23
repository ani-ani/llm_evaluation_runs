module intersperse (
  input [3:0] in_valid,
  input [3:0][7:0] in_data,
  input [7:0] delimiter,
  output reg [3:0] out_valid,
  output reg [7:0] out_data [7:0]
);

  integer i;
  always @* begin
    if (in_valid == 0) begin
      out_valid = 0;
      for (i = 0; i < 8; i = i + 1) begin
        out_data[i] = 8'b0;
      end
    end else begin
      out_valid = 2 * in_valid - 1;
      for (i = 0; i < 8; i = i + 1) begin
        out_data[i] = 8'b0;
      end
      out_data[0] = in_data[0];
      for (i = 1; i < in_valid; i = i + 1) begin
        out_data[2*i - 1] = delimiter;
        out_data[2*i] = in_data[i];
      end
    end
  end

endmodule