module TopModule(input clk, areset, x, output z);
  logic [1:0] state_reg;

  // Sequential state transition with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state_reg <= 2'b01; // Reset to state A (one-hot)
    end else begin
      case (state_reg)
        2'b01: state_reg <= x ? 2'b10 : 2'b01; // State A transitions
        2'b10: state_reg <= 2'b10; // State B (always remains)
        default: state_reg <= 2'b01; // Error recovery
      endcase
    end
  end

  // Mealy output (combinational)
  assign z = (state_reg == 2'b01) ? x : ~x;
endmodule