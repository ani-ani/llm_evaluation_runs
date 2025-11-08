module TopModule(
  input clk,
  input L,
  input q_in,
  input r_in,
  output reg Q
);

  // Data input selection: r_in when L=1, q_in when L=0
  wire data_in = L ? r_in : q_in;

  // Synchronous loadable flip-flop
  always @(posedge clk) begin
    Q <= data_in;
  end

endmodule