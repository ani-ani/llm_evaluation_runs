module TopModule(
  input  clk,
  input  L,
  input  q_in,
  input  r_in,
  output Q
);

  reg q_reg;
  wire mux_out;

  // 2:1 Multiplexer: select r_in when L=1, else q_in
  assign mux_out = L ? r_in : q_in;

  // Flip-flop
  always @(posedge clk) begin
    q_reg <= mux_out;
  end

  // Output
  assign Q = q_reg;

endmodule