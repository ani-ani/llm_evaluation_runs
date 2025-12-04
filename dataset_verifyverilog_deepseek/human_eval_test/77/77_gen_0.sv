module cube_checker (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] a,
  output reg is_cube,
  output reg done
);

  typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
  state_t state_reg, state_next;

  reg signed [7:0] n_reg, n_next;
  reg signed [31:0] a_latched;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_reg <= IDLE;
      n_reg <= -128;
      a_latched <= '0;
      is_cube <= '0;
      done <= '0;
    end else begin
      state_reg <= state_next;
      n_reg <= n_next;
      if (state_next == RUN && state_reg != RUN) a_latched <= { {16{a[15]}}, a };
      if (state_reg == RUN) begin
        is_cube <= (n_reg * n_reg * n_reg) == a_latched;
        done <= (n_reg * n_reg * n_reg) == a_latched || n_reg == 127;
      end else begin
        is_cube <= state_next == DONE ? is_cube : '0;
        done <= state_next == DONE;
      end
    end
  end

  always_comb begin
    n_next = n_reg;
    state_next = state_reg;

    case (state_reg)
      IDLE: begin
        if (start) begin
          state_next = RUN;
          n_next = -128;
        end
      end

      RUN: begin
        if (n_reg == 127 || (n_reg * n_reg * n_reg) == a_latched) begin
          state_next = DONE;
        end else begin
          n_next = n_reg + 1;
        end
      end

      DONE: begin
        if (start) begin
          state_next = RUN;
          n_next = -128;
        end else begin
          state_next = DONE;
        end
      end

      default: state_next = IDLE;
    endcase
  end
endmodule