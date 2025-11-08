module TopModule(
  input clk,
  input areset,
  input x,
  output reg z
);
  reg [1:0] state;

  // One-hot encoding: state[0] for A, state[1] for B
  parameter A = 2'b01;
  parameter B = 2'b10;

  // Asynchronous reset to A
  always @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= A;
    end else begin
      if (state[0]) begin  // Current state A
        if (x) begin
          state <= B;
        end else begin
          state <= A;
        end
      end else if (state[1]) begin  // Current state B
        state <= B;  // Always stay in B
      end
    end
  end

  // Mealy output
  always @(state or x) begin
    z = (state[0]) ? x : ~x;
  end

endmodule