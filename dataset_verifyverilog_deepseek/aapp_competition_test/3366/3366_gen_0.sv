module collatz_sum(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [15:0] R,
  output reg [20:0] S,
  output reg done
);

localparam MAX_ITER = 32;
localparam [1:0] IDLE = 2'b00,
                COMPUTE_FX = 2'b01,
                SUM_LOOP = 2'b10;

reg [1:0] state_reg, state_next;
reg [15:0] current_X_reg, current_X_next;
reg [15:0] temp_X_reg, temp_X_next;
reg [5:0] step_count_reg, step_count_next;
reg [5:0] iter_count_reg, iter_count_next;
reg [20:0] sum_reg, sum_next;
reg done_next;

// Sequential state and register updates
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state_reg <= IDLE;
    current_X_reg <= 0;
    temp_X_reg <= 0;
    step_count_reg <= 0;
    iter_count_reg <= 0;
    sum_reg <= 0;
    done <= 0;
    S <= 0;
  end else begin
    state_reg <= state_next;
    current_X_reg <= current_X_next;
    temp_X_reg <= temp_X_next;
    step_count_reg <= step_count_next;
    iter_count_reg <= iter_count_next;
    sum_reg <= sum_next;
    done <= done_next;
    // Gate S output until done
    S <= done_next ? sum_next : 0;
  end
end

// Combinational next-state logic
always_comb begin
  state_next = state_reg;
  current_X_next = current_X_reg;
  temp_X_next = temp_X_reg;
  step_count_next = step_count_reg;
  iter_count_next = iter_count_reg;
  sum_next = sum_reg;
  done_next = done;

  case (state_reg)
    IDLE: begin
      done_next = 0;
      if (start) begin
        state_next = COMPUTE_FX;
        current_X_next = L;
        temp_X_next = L;
        step_count_next = 0;
        iter_count_next = 0;
        sum_next = 0;
      end
    end

    COMPUTE_FX: begin
      if (temp_X_reg == 16'd1 || iter_count_reg == MAX_ITER) begin
        state_next = SUM_LOOP;
      end else begin
        if (temp_X_reg[0]) // Odd
          temp_X_next = temp_X_reg + 1;
        else               // Even
          temp_X_next = temp_X_reg >> 1;
        step_count_next = step_count_reg + 1;
        iter_count_next = iter_count_reg + 1;
      end
    end

    SUM_LOOP: begin
      sum_next = sum_reg + step_count_reg;
      current_X_next = current_X_reg + 1;
      if (current_X_reg < R) begin
        state_next = COMPUTE_FX;
        temp_X_next = current_X_next;
        step_count_next = 0;
        iter_count_next = 0;
      end else begin
        state_next = IDLE;
        done_next = 1;
      end
    end

    default: state_next = IDLE;
  endcase
end

endmodule