module prime_factorization (
  input clk,
  input rst_n,
  input start,
  input [15:0] n_in,
  output reg [7:0] factors [0:15],
  output reg [3:0] factor_count,
  output reg valid
);

typedef enum logic [1:0] {IDLE, DIVIDE, INCREMENT, DONE} state_t;
state_t state, next_state;

reg [15:0] divisor, remainder;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    divisor <= 2;
    remainder <= 0;
    factor_count <= 0;
    valid <= 0;
    for (int i = 0; i < 16; i++) begin
      factors[i] <= 8'b0;
    end
  end else begin
    state <= next_state;
    case (state)
      IDLE: begin
        valid <= 0;
        if (start) begin
          divisor <= 2;
          remainder <= n_in;
          factor_count <= 0;
        end
      end
      DIVIDE: begin
        if (remainder != 1 && remainder != 0) begin
          if (remainder % divisor == 0) begin
            factors[factor_count] <= divisor[7:0];
            factor_count <= factor_count + 1;
            remainder <= remainder / divisor;
          end
        end
      end
      INCREMENT: divisor <= divisor + 1;
      DONE: valid <= 1;
    endcase
  end
end

always_comb begin
  next_state = state;
  case (state)
    IDLE: if (start) next_state = DIVIDE;
    DIVIDE: begin
      if (remainder == 1) begin
        next_state = DONE;
      end else if (remainder % divisor != 0) begin
        next_state = INCREMENT;
      end else begin
        next_state = DIVIDE;
      end
    end
    INCREMENT: next_state = DIVIDE;
    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

endmodule