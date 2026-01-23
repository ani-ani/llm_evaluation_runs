module new_tuple (
  input [7:0][7:0] list_data,
  input [2:0] list_length,
  input [7:0] append_str,
  output reg [8:0][7:0] result_tuple,
  output reg [2:0] result_length
);

  integer i;
  always @* begin
    result_length = list_length + 1;
    for (i = 0; i < list_length; i = i + 1) begin
      result_tuple[i] = list_data[i];
    end
    result_tuple[list_length] = append_str;
  end

endmodule