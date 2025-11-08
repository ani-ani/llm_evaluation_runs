module TopModule(input clk, input areset, input x, output logic z);
  typedef enum {IDLE, FLIP} state_t;
  state_t state, next_state;
  logic next_z;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= IDLE;
      z <= 1'b0;
    end else begin
      state <= next_state;
      z <= next_z;
    end
  end

  always_comb begin
    case (state)
      IDLE: next_state = x ? FLIP : IDLE;
      FLIP: next_state = FLIP;
    endcase
  end

  always_comb begin
    case (state)
      IDLE: next_z = x;
      FLIP: next_z = ~x;
    endcase
  end
endmodule