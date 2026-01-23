module count_occurrence (
  input [7:0] tuple_data,
  input [2:0] tuple_len,
  input [7:0] list_data,
  input [2:0] list_len,
  output [3:0] result
);

  reg [3:0] count = 0;
  integer i, j;

  always @* begin
    count = 0;
    for (i = 0; i < tuple_len; i = i + 1) begin
      for (j = 0; j < list_len; j = j + 1) begin
        if (tuple_data[8*i +: 8] == list_data[8*j +: 8]) begin
          count = count + 1;
        end
      end
    end
  end

  assign result = count;

endmodule