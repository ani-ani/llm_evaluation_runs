module remove_duplicates (
  input [7:0] data_in_0,
  input [7:0] data_in_1,
  input [7:0] data_in_2,
  input [7:0] data_in_3,
  input [7:0] data_in_4,
  input [7:0] data_in_5,
  input [7:0] data_in_6,
  input [7:0] data_in_7,
  input [2:0] valid_count,
  output [7:0] unique_0,
  output [7:0] unique_1,
  output [7:0] unique_2,
  output [7:0] unique_3,
  output [7:0] unique_4,
  output [7:0] unique_5,
  output [7:0] unique_6,
  output [7:0] unique_7,
  output [3:0] unique_count
);

  reg [7:0] data_in [0:7];
  reg [7:0] unique_out [0:7];
  reg [3:0] count;
  integer i, j, k;

  assign data_in[0] = data_in_0;
  assign data_in[1] = data_in_1;
  assign data_in[2] = data_in_2;
  assign data_in[3] = data_in_3;
  assign data_in[4] = data_in_4;
  assign data_in[5] = data_in_5;
  assign data_in[6] = data_in_6;
  assign data_in[7] = data_in_7;

  always @* begin
    count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      unique_out[i] = 8'hFF;
    end

    for (i = 0; i < valid_count; i = i + 1) begin
      reg is_unique = 1'b1;
      for (j = 0; j < valid_count; j = j + 1) begin
        if (i != j && data_in[i] == data_in[j]) begin
          is_unique = 1'b0;
        end
      end

      if (is_unique) begin
        unique_out[count] = data_in[i];
        count = count + 1;
      end
    end

    unique_0 = unique_out[0];
    unique_1 = unique_out[1];
    unique_2 = unique_out[2];
    unique_3 = unique_out[3];
    unique_4 = unique_out[4];
    unique_5 = unique_out[5];
    unique_6 = unique_out[6];
    unique_7 = unique_out[7];
    unique_count = count;
  end

endmodule