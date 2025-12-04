module fun_maximizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_coasters,
  input [6:0] a1, a2, a3, a4,
  input [6:0] b1, b2, b3, b4,
  input [3:0] t1, t2, t3, t4,
  input [3:0] T,
  output reg [15:0] max_fun,
  output reg done
);

  // State encoding
  localparam [1:0]
    S_IDLE  = 2'd0,
    S_LOAD  = 2'd1,
    S_CALC  = 2'd2,
    S_DONE  = 2'd3;

  reg [1:0]  state, next_state;

  // Latched configuration
  reg [3:0]  cfg_num_coasters;
  reg [3:0]  cfg_T;

  reg [6:0]  a_reg [0:3];
  reg [6:0]  b_reg [0:3];
  reg [3:0]  t_reg [0:3];

  // DP arrays: 0..15
  reg [15:0] dp_cur [0:15];
  reg [15:0] dp_next[0:15];

  // Loop indices
  reg [3:0] time_idx;     // 0..15
  reg [1:0] coaster_idx;  // 0..3

  // Ride expansion state
  reg [6:0] cur_a;              // a_i
  reg [6:0] cur_b;              // b_i
  reg [3:0] cur_t;              // t_i

  reg [7:0] k;                  // ride count index
  reg [7:0] k_minus1;
  reg [15:0] sq;                // (k-1)^2
  reg [13:0] mult_res;          // b_i * (k-1)^2 (7b * up to 49)
  reg [8:0] fun_raw;            // up to 255
  reg [8:0] fun_pos;            // clipped to >=0

  reg [7:0] cost;               // cost = k * t_i (<= 15*15=225, but T<=15 so large cost auto skipped)

  reg [15:0] candidate;

  // Control flags
  reg expanding;                // indicates we are expanding rides for current coaster/time
  reg [3:0] base_time;          // current base time (j) under consideration

  integer i;

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_LOAD;
      end
      S_LOAD: begin
        next_state = S_CALC;
      end
      S_CALC: begin
        // Transition controlled in sequential block when all loops complete
        // Default stay in CALC here
        next_state = state;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential state, datapath, and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done  <= 1'b0;
      max_fun <= 16'd0;
      cfg_num_coasters <= 4'd0;
      cfg_T <= 4'd0;
      coaster_idx <= 2'd0;
      time_idx <= 4'd0;
      expanding <= 1'b0;
      base_time <= 4'd0;
      k <= 8'd0;
      cur_a <= 7'd0;
      cur_b <= 7'd0;
      cur_t <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        dp_cur[i] <= 16'd0;
        dp_next[i] <= 16'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          max_fun <= 16'd0;
          if (start) begin
            // Latch inputs
            cfg_num_coasters <= (num_coasters > 4'd4) ? 4'd4 : num_coasters;
            cfg_T <= (T > 4'd15) ? 4'd15 : T;

            a_reg[0] <= a1; a_reg[1] <= a2; a_reg[2] <= a3; a_reg[3] <= a4;
            b_reg[0] <= b1; b_reg[1] <= b2; b_reg[2] <= b3; b_reg[3] <= b4;
            t_reg[0] <= (t1 == 4'd0) ? 4'd1 : t1;
            t_reg[1] <= (t2 == 4'd0) ? 4'd1 : t2;
            t_reg[2] <= (t3 == 4'd0) ? 4'd1 : t3;
            t_reg[3] <= (t4 == 4'd0) ? 4'd1 : t4;
          end
        end

        S_LOAD: begin
          // Initialize DP for 0 items: dp_cur[0..T] = 0
          for (i = 0; i < 16; i = i + 1) begin
            dp_cur[i] <= 16'd0;
            dp_next[i] <= 16'd0;
          end
          coaster_idx <= 2'd0;
          time_idx    <= 4'd0;
          base_time   <= 4'd0;
          expanding   <= 1'b0;
          k           <= 8'd0;
        end

        S_CALC: begin
          // If no coasters or T==0, finish quickly
          if (cfg_num_coasters == 4'd0 || cfg_T == 4'd0) begin
            max_fun <= 16'd0;
            done <= 1'b1;
          end else begin
            // Coaster loop control
            if (coaster_idx >= cfg_num_coasters) begin
              // All coasters processed: result is dp_cur[T]
              max_fun <= dp_cur[cfg_T];
              done <= 1'b1;
            end else begin
              done <= 1'b0;

              // If starting a new coaster
              if (!expanding && time_idx == 4'd0 && base_time == 4'd0 && k == 8'd0) begin
                // Load current coaster parameters
                cur_a <= a_reg[coaster_idx];
                cur_b <= b_reg[coaster_idx];
                cur_t <= t_reg[coaster_idx];

                // Initialize dp_next with dp_cur (0 occurrences of this coaster)
                for (i = 0; i < 16; i = i + 1) begin
                  dp_next[i] <= dp_cur[i];
                end

                // Setup expansion for this coaster
                time_idx  <= 4'd0;
                base_time <= 4'd0;
                k         <= 8'd1;   // first ride count
                expanding <= 1'b1;
              end else if (expanding) begin
                // Expanding rides for current coaster: unbounded knap with decreasing fun

                // Process one (base_time, k) pair per cycle
                // Compute base_time from time_idx (j)
                base_time <= time_idx;

                // Compute cost = k * cur_t
                cost <= k * cur_t;

                // Compute (k-1)^2
                k_minus1 <= (k == 0) ? 8'd0 : (k - 8'd1);
                sq <= k_minus1 * k_minus1;

                // Multiply with cur_b
                mult_res <= sq * cur_b; // 7b * up to 49 -> fits in 13b

                // fun_raw = cur_a - mult_res (saturate at 0)
                if (cur_a > mult_res[6:0]) begin
                  fun_raw <= cur_a - mult_res[6:0];
                end else begin
                  fun_raw <= 9'd0;
                end

                // Clip negative
                if (fun_raw[8] == 1'b1) begin
                  fun_pos <= 9'd0;
                end else begin
                  fun_pos <= fun_raw;
                end

                // Apply update only if cost <= cfg_T and fun_pos > 0
                if (cost != 0 && cost <= cfg_T && fun_pos > 0) begin
                  if (base_time + cost <= cfg_T) begin
                    candidate = dp_next[base_time] + fun_pos;
                    if (candidate > dp_next[base_time + cost]) begin
                      dp_next[base_time + cost] <= candidate;
                    end
                  end
                end

                // Advance indices
                if (time_idx < cfg_T) begin
                  time_idx <= time_idx + 4'd1; // move to next base_time
                end else begin
                  time_idx <= 4'd0;
                  // move to next ride count
                  k <= k + 8'd1;
                  // termination condition: when even for base_time=0 cost>cfg_T or fun<=0
                  // approximate early stop using cost and fun_pos
                  if ((k * cur_t) > cfg_T || fun_pos == 0) begin
                    // finish expansion for this coaster
                    expanding <= 1'b0;
                    k <= 8'd0;

                    // Move dp_next to dp_cur for next coaster or to result
                    for (i = 0; i <= 15; i = i + 1) begin
                      dp_cur[i] <= dp_next[i];
                    end

                    // Next coaster
                    coaster_idx <= coaster_idx + 2'd1;
                  end
                end

              end else begin
                // Waiting/setup between coasters (should rarely hit)
                expanding <= 1'b0;
              end
            end
          end
        end

        S_DONE: begin
          // Hold result until start deasserted and FSM returns to IDLE
          done <= 1'b1;
        end

        default: begin
          // Should not occur
        end
      endcase

      // Force transition from CALC to DONE when done asserted
      if (state == S_CALC && done) begin
        state <= S_DONE;
      end
    end
  end

endmodule