module string_to_tuple (
  input [7:0] char_0,
  input [7:0] char_1,
  input [7:0] char_2,
  input [7:0] char_3,
  input [7:0] char_4,
  input [7:0] char_5,
  input [7:0] char_6,
  input [7:0] char_7,
  output [7:0] result_0,
  output [7:0] result_1,
  output [7:0] result_2,
  output [7:0] result_3,
  output [7:0] result_4,
  output [7:0] result_5,
  output [7:0] result_6,
  output [7:0] result_7,
  output [3:0] count
);

  wire [7:0] chars [0:7] = '{char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7};
  wire [7:0] results [0:7];
  integer i, j;

  always_comb begin
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (chars[i] != 8'h20) begin
        results[j] = chars[i];
        j = j + 1;
      end
    end
    for (; j < 8; j = j + 1) begin
      results[j] = 8'h00;
    end
  end

  assign result_0 = results[0];
  assign result_1 = results[1];
  assign result_2 = results[2];
  assign result_3 = results[3];
  assign result_4 = results[4];
  assign result_5 = results[5];
  assign result_6 = results[6];
  assign result_7 = results[7];

  assign count = 4'h0;
  always_comb begin
    count = 4'h0;
    for (i = 0; i < 8; i = i + 1) begin
      if (chars[i] != 8'h20) begin
        count = count + 1;
      end
    end
  end

endmodule