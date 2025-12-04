module buffet_optimizer(
  input clk,
  input rst_n,
  input start,
  input [1:0] dish_type [0:3],
  input [7:0] w_i [0:3],
  input [7:0] t_i [0:3],
  input [7:0] dt_i [0:3],
  input [7:0] target_w,
  output reg [15:0] max_taste,
  output reg impossible,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_CALC  = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;
  logic [1:0] dish_idx, next_dish_idx;
  logic [1:0] phase, next_phase;
  logic [7:0] rem_weight, next_rem_weight;
  logic [31:0] sum, next_sum;
  logic [7:0] N, next_N;          // for discrete dishes
  logic [7:0] X, next_X;          // for continuous dishes
  logic [31:0] contrib, next_contrib; // current dish contribution (Q8.8)
  logic [7:0] new_rem_weight, next_new_rem_weight;
  logic [15:0] next_max_taste;
  logic next_done;                // used to generate the done pulse

  // Current dish data (selected by dish_idx)
  logic [1:0] cur_type;
  logic [7:0] cur_w, cur_t, cur_dt;

  always_comb begin
    // Default next values = current
    next_state      = state;
    next_dish_idx   = dish_idx;
    next_phase      = phase;
    next_rem_weight = rem_weight;
    next_sum        = sum;
    next_max_taste  = max_taste;
    next_N          = N;
    next_X          = X;
    next_contrib    = contrib;
    next_new_rem_weight = new_rem_weight;
    next_done       = 1'b0;
    impossible      = 1'b0; // never impossible in this implementation

    // Select current dish data
    cur_type = dish_type[dish_idx];
    cur_w    = w_i[dish_idx];
    cur_t    = t_i[dish_idx];
    cur_dt   = dt_i[dish_idx];

    // State transition logic
    case (state)
      S_IDLE: begin
        if (start) begin
          next_state      = S_CALC;
          next_rem_weight = target_w;
          next_sum        = 32'b0;
          next_dish_idx   = 2'b0;
          next_phase      = 2'b0;
          // reset temporaries
          next_N          = 8'b0;
          next_X          = 8'b0;
          next_contrib    = 32'b0;
          next_new_rem_weight = 8'b0;
        end
      end
      S_CALC: begin
        // Advance phase each clock
        next_phase = phase + 1'b1;
        // If this is the last phase of the last dish, go to DONE
        if (dish_idx == 2'b11 && phase == 2'b11) begin
          next_state = S_DONE;
        end
      end
      S_DONE: begin
        next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase

    // Per‑phase processing for the CALC state
    if (state == S_CALC) begin
      case (phase)
        2'b00: begin
          // Phase 0: compute N (discrete) or X (continuous)
          if (cur_type == 2'b00) begin
            // Discrete dish: number of whole items that fit
            if (cur_w == 8'b0) begin
              next_N = 8'b0;
            end else begin
              next_N = rem_weight / cur_w; // integer division, floor
            end
            next_X = 8'b0;
          end else begin
            // Continuous dish: optimal weight X = min(rem, t_i/dt_i)
            if (cur_dt == 8'b0) begin
              // No decay → take all remaining weight
              next_X = rem_weight;
            end else begin
              // X_opt = (t_i * 16) / dt_i  (both inputs are 8‑bit)
              logic [15:0] tmp_opt;
              tmp_opt = (16'(cur_t) * 16'd16) / cur_dt; // up to 12‑bit result
              if (tmp_opt > 16'd255) next_X = 8'd255;
              else next_X = tmp_opt[7:0];
            end
            next_N = 8'b0;
          end
        end
        2'b01: begin
          // Phase 1: compute contribution for the current dish
          if (cur_type == 2'b00) begin
            // Discrete contribution: N*t_i - dt_i*N*(N-1)/2  (scaled to Q8.8)
            logic [15:0] n;
            logic [15:0] n_minus_one;
            logic [15:0] n_times_nminus1_div2;
            n = N;
            n_minus_one = n - 1;
            n_times_nminus1_div2 = (n * n_minus_one) >> 1;
            logic [31:0] tmp1, tmp2;
            tmp1 = 32'(n) * 32'(cur_t);
            tmp2 = 32'(cur_dt) * 32'(n_times_nminus1_div2);
            next_contrib = (tmp1 - tmp2) << 8; // scale to Q8.8
          end else begin
            // Continuous contribution: t_i*X - 0.5*dt_i*X^2  (Q8.8)
            logic [15:0] X_88;                // X in Q8.8 (X * 16)
            logic [31:0] term1;
            logic [31:0] term2_raw;
            logic [31:0] term2_q88;
            X_88 = {X, 4'b0};                // X * 16 (Q8.8)
            term1     = 32'(cur_t) * 32'(X_88);
            term2_raw = 32'(cur_dt) * X_88 * X_88;
            // Divide by 2 and scale to Q8.8 (shift right by 9)
            term2_q88 = term2_raw >> 9;
            next_contrib = term1 - term2_q88;
          end
        end
        2'b10: begin
          // Phase 2: compute the new remaining weight
          if (cur_type == 2'b00) begin
            // Discrete: weight consumed = N * w_i
            next_new_rem_weight = rem_weight - (N * cur_w);
          end else begin
            // Continuous: weight consumed = X
            next_new_rem_weight = rem_weight - X;
          end
        end
        2'b11: begin
          // Phase 3: update total taste and remaining weight, advance dish index
          next_sum = sum + contrib;
          next_rem_weight = new_rem_weight;
          if (dish_idx != 2'b11) begin
            next_dish_idx = dish_idx + 1;
          end else begin
            next_dish_idx = dish_idx; // will be ignored – state moves to DONE
          end
          // Clear temporaries for the next dish
          next_N = 8'b0;
          next_X = 8'b0;
          next_contrib = 32'b0;
          next_new_rem_weight = 8'b0;
        end
        default: ;
      endcase
    end

    // Set max_taste and done when in DONE state
    if (state == S_DONE) begin
      next_max_taste = sum[15:0];
      next_done = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      dish_idx     <= 2'b0;
      phase        <= 2'b0;
      rem_weight   <= 8'b0;
      sum          <= 32'b0;
      max_taste    <= 16'b0;
      N            <= 8'b0;
      X            <= 8'b0;
      contrib      <= 32'b0;
      new_rem_weight <= 8'b0;
      done         <= 1'b0;
      impossible   <= 1'b0;
    end else begin
      state        <= next_state;
      dish_idx     <= next_dish_idx;
      phase        <= next_phase;
      rem_weight   <= next_rem_weight;
      sum          <= next_sum;
      max_taste    <= next_max_taste;
      N            <= next_N;
      X            <= next_X;
      contrib      <= next_contrib;
      new_rem_weight <= next_new_rem_weight;
      done         <= next_done;
      impossible   <= 1'b0;
    end
  end

endmodule