module list_rotator(
  input  [3:0] data_in [7:0],
  input  [2:0] m,
  output reg [3:0] data_out [7:0]
);

  integer i;
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      data_out[i] = data_in[(i - m) & 3'b111];
    end
  end

endmodule