module add_numbers (
  input reg [11:0] a,
  input reg [11:0] b,
  output reg [12:0] sum
);
  // Combinational sum: sum = a + b
  always @(*) begin
    sum = a + b;
  end
endmodule