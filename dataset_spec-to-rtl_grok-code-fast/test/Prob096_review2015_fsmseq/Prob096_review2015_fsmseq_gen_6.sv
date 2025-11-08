module TopModule (
  input logic clk,
  input logic reset,
  input logic data,
  output logic start_shifting
);
  logic [3:0] shift_reg;
  logic found;
  
  always @(posedge clk) begin
    if (reset) begin
      shift_reg <= 4'b0000;
      found <= 1'b0;
    end else begin
      shift_reg <= {shift_reg[2:0], data};
      if (shift_reg == 4'b1101) begin
        found <= 1'b1;
      end
    end
  end
  
  assign start_shifting = found;
endmodule