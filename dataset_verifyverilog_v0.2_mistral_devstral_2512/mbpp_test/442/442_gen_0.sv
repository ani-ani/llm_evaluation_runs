module positive_ratio (
  input [7:0] data_in,
  input [2:0] index,
  input valid,
  output reg [31:0] result,
  output reg result_valid
);

  reg [2:0] count = 0;
  reg [2:0] prev_index = 0;

  always @* begin
    if (valid) begin
      if (index == 0) begin
        count = 0;
      end
      if (data_in > 0) begin
        count = count + 1;
      end
      if (index == 7 && prev_index != 7) begin
        result = count << 13;
        result_valid = 1;
      end else begin
        result_valid = 0;
      end
      prev_index = index;
    end else begin
      result_valid = 0;
    end
  end

endmodule