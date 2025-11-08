module TopModule(
  input  clk,
  input  L,
  input  q_in,
  input  r_in,
  output Q
);

  reg q_reg;
  wire mux_out;

  // 2:1 Multiplexer
  assign mux_out = L ? r_in : q_in;

  // Flip-flop
  always @(posedge clk) begin
    q_reg <= mux_out;
  end

  // Output assignment
  assign Q = q_reg;

endmodule