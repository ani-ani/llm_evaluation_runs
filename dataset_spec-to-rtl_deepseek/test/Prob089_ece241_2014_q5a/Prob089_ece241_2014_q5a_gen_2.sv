module TopModule(input clk, input areset, input x, output logic z);
  localparam StateA = 1'b0;
  localparam StateB = 1'b1;
  logic current_state, next_state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) current_state <= StateA;
    else        current_state <= next_state;
  end

  always_comb begin
    case (current_state)
      StateA: begin
        z = x;
        next_state = x ? StateB : StateA;
      end
      StateB: begin
        z = ~x;
        next_state = StateB;
      end
      default: begin
        z = 1'b0;
        next_state = StateA;
      end
    endcase
  end
endmodule