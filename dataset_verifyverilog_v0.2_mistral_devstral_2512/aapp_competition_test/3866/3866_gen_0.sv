module lucky_permutation #(
  parameter MAX_N = 16
)(
  input clk,
  input rst_n,
  input start,
  input [7:0] n_in,
  output [3:0] a_out,
  output [3:0] b_out,
  output [3:0] c_out,
  output [3:0] index_out,
  output valid,
  output done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  // Internal signals
  state_t state, next_state;
  logic [3:0] index_reg, index_next;
  logic [3:0] a_reg, b_reg, c_reg;
  logic valid_reg, done_reg;
  logic start_reg, start_next;
  logic [7:0] n_reg, n_next;

  // State transition logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index_reg <= 0;
      valid_reg <= 0;
      done_reg <= 0;
      start_reg <= 0;
      n_reg <= 0;
    end else begin
      state <= next_state;
      index_reg <= index_next;
      valid_reg <= (next_state == PROCESSING);
      done_reg <= (next_state == DONE);
      start_reg <= start_next;
      n_reg <= n_next;
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    index_next = index_reg;
    start_next = start;
    n_next = n_in;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          index_next = 0;
        end
      end

      PROCESSING: begin
        if (index_reg == n_reg - 1) begin
          next_state = DONE;
        end else begin
          index_next = index_reg + 1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Output computation
  always_comb begin
    a_reg = index_reg;
    b_reg = index_reg;
    if (2 * index_reg < n_reg) begin
      c_reg = 2 * index_reg;
    end else begin
      c_reg = 2 * index_reg - n_reg;
    end
  end

  // Output assignments
  assign a_out = a_reg;
  assign b_out = b_reg;
  assign c_out = c_reg;
  assign index_out = index_reg;
  assign valid = valid_reg;
  assign done = done_reg;

endmodule