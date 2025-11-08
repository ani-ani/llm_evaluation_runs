module TopModule(
  input logic clk,
  input logic reset,
  input logic j,
  input logic k,
  output logic out
);

  localparam OFF = 1'b0;
  localparam ON = 1'b1;

  logic state;

  always @(posedge clk) begin
    if (reset) begin
      state <= OFF;
    end else begin
      if (state == OFF) begin
        if (j) state <= ON;
        else state <= OFF;
      end else begin
        if (k) state <= OFF;
        else state <= ON;
      end
    end
  end

  assign out = (state == ON) ? 1'b1 : 1'b0;

endmodule