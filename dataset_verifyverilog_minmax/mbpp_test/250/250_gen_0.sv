module count_element (
  input reg [63:0] array_data,
  input reg [3:0] target,
  output reg [3:0] count
);
  integer i;
  always @(*) begin
    count = 4'd0;
    for (i = 0; i < 12; i = i + 1) begin
      if (array_data[i*4 +: 4] == target) count = count + 1;
    end
  end
endmodule