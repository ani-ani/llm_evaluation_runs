module dog_feeding_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [7:0] eating_times_0_0, input [7:0] eating_times_0_1, input [7:0] eating_times_0_2, input [7:0] eating_times_0_3, input [7:0] eating_times_0_4, input [7:0] eating_times_0_5,
  input [7:0] eating_times_1_0, input [7:0] eating_times_1_1, input [7:0] eating_times_1_2, input [7:0] eating_times_1_3, input [7:0] eating_times_1_4, input [7:0] eating_times_1_5,
  input [7:0] eating_times_2_0, input [7:0] eating_times_2_1, input [7:0] eating_times_2_2, input [7:0] eating_times_2_3, input [7:0] eating_times_2_4, input [7:0] eating_times_2_5,
  input [7:0] eating_times_3_0, input [7:0] eating_times_3_1, input [7:0] eating_times_3_2, input [7:0] eating_times_3_3, input [7:0] eating_times_3_4, input [7:0] eating_times_3_5,
  output reg [9:0] result,
  output reg done
);

  // Internal bowl index registers for up to 4 dogs
  reg [2:0] b0, b1, b2, b3;

  // Maximum valid index = m-1
  reg [2:0] max_idx;

  // Current and best cost
  reg [9:0] curr_T;
  reg [9:0] best_T;

  // Control FSM
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_CHECK  = 3'd2,
    S_UPDATE = 3'd3,
    S_NEXT   = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Combinational wires for eating times selected by bowl indices
  reg [7:0] t0, t1, t2, t3;

  // Helper: select time for given dog and bowl index
  function automatic [7:0] sel_time;
    input [1:0] dog;
    input [2:0] bowl;
    begin
      unique case (dog)
        2'd0: begin
          unique case (bowl)
            3'd0: sel_time = eating_times_0_0;
            3'd1: sel_time = eating_times_0_1;
            3'd2: sel_time = eating_times_0_2;
            3'd3: sel_time = eating_times_0_3;
            3'd4: sel_time = eating_times_0_4;
            default: sel_time = eating_times_0_5;
          endcase
        end
        2'd1: begin
          unique case (bowl)
            3'd0: sel_time = eating_times_1_0;
            3'd1: sel_time = eating_times_1_1;
            3'd2: sel_time = eating_times_1_2;
            3'd3: sel_time = eating_times_1_3;
            3'd4: sel_time = eating_times_1_4;
            default: sel_time = eating_times_1_5;
          endcase
        end
        2'd2: begin
          unique case (bowl)
            3'd0: sel_time = eating_times_2_0;
            3'd1: sel_time = eating_times_2_1;
            3'd2: sel_time = eating_times_2_2;
            3'd3: sel_time = eating_times_2_3;
            3'd4: sel_time = eating_times_2_4;
            default: sel_time = eating_times_2_5;
          endcase
        end
        default: begin
          unique case (bowl)
            3'd0: sel_time = eating_times_3_0;
            3'd1: sel_time = eating_times_3_1;
            3'd2: sel_time = eating_times_3_2;
            3'd3: sel_time = eating_times_3_3;
            3'd4: sel_time = eating_times_3_4;
            default: sel_time = eating_times_3_5;
          endcase
        end
      endcase
    end
  endfunction

  // Calculate cost for current assignment (combinational)
  always @(*) begin
    // Default values
    t0 = 8'd0;
    t1 = 8'd0;
    t2 = 8'd0;
    t3 = 8'd0;

    // For each active dog, get its assigned bowl time
    if (n >= 3'd1) t0 = sel_time(2'd0, b0);
    if (n >= 3'd2) t1 = sel_time(2'd1, b1);
    if (n >= 3'd3) t2 = sel_time(2'd2, b2);
    if (n >= 3'd4) t3 = sel_time(2'd3, b3);

    // Find max time among active dogs
    reg [7:0] max_t;
    max_t = 8'd0;
    if (n >= 3'd1 && t0 > max_t) max_t = t0;
    if (n >= 3'd2 && t1 > max_t) max_t = t1;
    if (n >= 3'd3 && t2 > max_t) max_t = t2;
    if (n >= 3'd4 && t3 > max_t) max_t = t3;

    // Sum waiting times = sum(max_t - ti)
    reg [9:0] sum_T;
    sum_T = 10'd0;
    if (n >= 3'd1) sum_T = sum_T + (max_t - t0);
    if (n >= 3'd2) sum_T = sum_T + (max_t - t1);
    if (n >= 3'd3) sum_T = sum_T + (max_t - t2);
    if (n >= 3'd4) sum_T = sum_T + (max_t - t3);

    curr_T = sum_T;
  end

  // Check if current bowl indices are a valid permutation (no reuse among first n bowls)
  function automatic logic is_valid_perm;
    input [2:0] fb0, fb1, fb2, fb3;
    input [2:0] fn;
    begin
      is_valid_perm = 1'b1;
      if (fn >= 3'd2 && fb1 == fb0) is_valid_perm = 1'b0;
      if (fn >= 3'd3 && (fb2 == fb0 || fb2 == fb1)) is_valid_perm = 1'b0;
      if (fn >= 3'd4 && (fb3 == fb0 || fb3 == fb1 || fb3 == fb2)) is_valid_perm = 1'b0;
    end
  endfunction

  // Detect last combination in n-digit base-m counter
  function automatic logic is_last_comb;
    input [2:0] fb0, fb1, fb2, fb3;
    input [2:0] fn;
    input [2:0] fmax;
    begin
      case (fn)
        3'd2: is_last_comb = (fb0 == fmax && fb1 == fmax);
        3'd3: is_last_comb = (fb0 == fmax && fb1 == fmax && fb2 == fmax);
        default: is_last_comb = (fb0 == fmax && fb1 == fmax && fb2 == fmax && fb3 == fmax);
      endcase
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_CHECK;
      end
      S_CHECK: begin
        if (is_valid_perm(b0, b1, b2, b3, n))
          next_state = S_UPDATE;
        else if (is_last_comb(b0, b1, b2, b3, n, max_idx))
          next_state = S_DONE;
        else
          next_state = S_NEXT;
      end
      S_UPDATE: begin
        if (is_last_comb(b0, b1, b2, b3, n, max_idx))
          next_state = S_DONE;
        else
          next_state = S_NEXT;
      end
      S_NEXT: begin
        next_state = S_CHECK;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      done    <= 1'b0;
      result  <= 10'd0;
      best_T  <= 10'd0;
      max_idx <= 3'd0;
      b0 <= 3'd0;
      b1 <= 3'd0;
      b2 <= 3'd0;
      b3 <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done   <= 1'b0;
          if (start) begin
            max_idx <= (m > 0) ? (m - 1) : 3'd0;
          end
        end

        S_INIT: begin
          // Initialize base-m counter and best_T to max
          b0 <= 3'd0;
          b1 <= 3'd0;
          b2 <= 3'd0;
          b3 <= 3'd0;
          best_T <= 10'h3FF; // large initial value (1023)
          done <= 1'b0;
        end

        S_CHECK: begin
          // No register updates here; decisions handled in next_state
        end

        S_UPDATE: begin
          // Update best_T and result if current permutation is better
          if (curr_T < best_T) begin
            best_T <= curr_T;
            result <= curr_T;
          end
        end

        S_NEXT: begin
          // Increment n-digit base-m counter for active dogs
          if (n >= 3'd1) begin
            if (b0 == max_idx)
              b0 <= 3'd0;
            else
              b0 <= b0 + 3'd1;
          end

          if (n >= 3'd2) begin
            if (b0 == 3'd0) begin
              if (b1 == max_idx)
                b1 <= 3'd0;
              else
                b1 <= b1 + 3'd1;
            end
          end

          if (n >= 3'd3) begin
            if (b0 == 3'd0 && b1 == 3'd0) begin
              if (b2 == max_idx)
                b2 <= 3'd0;
              else
                b2 <= b2 + 3'd1;
            end
          end

          if (n >= 3'd4) begin
            if (b0 == 3'd0 && b1 == 3'd0 && b2 == 3'd0) begin
              if (b3 == max_idx)
                b3 <= 3'd0;
              else
                b3 <= b3 + 3'd1;
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold result as best_T (already tracked)
          result <= best_T;
        end

        default: ;
      endcase
    end
  end

endmodule