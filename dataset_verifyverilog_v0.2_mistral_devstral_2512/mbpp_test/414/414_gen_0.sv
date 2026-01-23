module array_overlap (
  input [7:0] array1 [0:7],
  input [7:0] array2 [0:7],
  output reg overlap
);

  reg [7:0] match [0:7];
  integer i, j;

  always @* begin
    overlap = 1'b0;
    for (i = 0; i < 8; i = i + 1) begin
      match[i] = 1'b0;
      for (j = 0; j < 8; j = j + 1) begin
        match[i] = match[i] | (array1[i] == array2[j]);
      end
      overlap = overlap | match[i];
    end
  end

endmodule