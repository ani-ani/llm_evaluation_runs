module TopModule(
  input clk,
  input reset,
  input in,
  output out
);

  localparam A = 1'b0;
  localparam B = 1'b1;

  reg state;

  always @(posedge clk) begin
    if (reset) begin
      state <= B;
    end else begin
      case (state)
        B: if (in == 1'b0) state <= A;
        A: if (in == 1'b0) state <= B;
      endcase
    end
  end

  assign out = (state == B) ? 1'b1 : 1'b0;

endmodule