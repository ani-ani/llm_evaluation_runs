module TopModule(input clk, input reset, input in, output out);
  localparam B = 1'b1;
  localparam A = 1'b0;
  reg state_reg;
  reg state_next;

  always_ff @(posedge clk) begin
    if (reset)
      state_reg <= B;
    else
      state_reg <= state_next;
  end

  always_comb begin
    case (state_reg)
      B: state_next = in ? B : A;
      A: state_next = in ? A : B;
      default: state_next = B;
    endcase
  end

  assign out = state_reg;
endmodule