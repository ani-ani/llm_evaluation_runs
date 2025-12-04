module team_selector(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse to start computation
  input [2:0] k, // team size (1-8)
  input [2:0] n, // number of employees (1-8)
  input [15:0] s_arr [0:7], // salaries (16-bit each)
  input [15:0] p_arr [0:7], // productivities (16-bit each)
  input [2:0] r_arr [0:7], // recommenders (employee numbers)
  output reg [31:0] max_ratio, // Q16.16 fixed-point format
  output reg done // high when result valid
);

  // State machine states
  typedef enum logic [1:0] {
    ST_IDLE  = 2'b00,
    ST_ITER  = 2'b01,
    ST_DIV   = 2'b10,
    ST_DONE  = 2'b11
  } state_t;

  state_t state;

  // Iteration and division counters
  reg [7:0] subset_idx;        // 0..255 (2^8)
  reg [7:0] subset_max;        // 2^n - 1
  reg [5:0] div_cnt;           // 0..31 for 32-cycle division
  reg [7:0] best_sum_s;
  reg [15:0] best_sum_p;

  // Pipeline: compute new sums for next subset by flipping lowest set bit
  reg [7:0] prev_sum_s;
  reg [15:0] prev_sum_p;
  reg [7:0] next_sum_s;
  reg [15:0] next_sum_p;
  reg [3:0] lsb;               // index of lowest set bit (0..7)
  reg [2:0] delta_k;           // popcount delta (+1 or -1)
  reg prev_valid;              // validity of previous subset
  reg next_valid;              // validity of next subset

  // Flags for current subset
  reg cur_valid;
  reg [3:0] cur_k;             // current subset popcount
  reg [15:0] cur_sum_p;
  reg [7:0] cur_sum_s;

  // Internal signals for validation
  reg [2:0] i_emp;             // employee index for validation
  reg [7:0] cur_mask;          // 8-bit mask for current subset
  reg mask_bit;
  reg [2:0] recommender;
  reg rec_bit;
  reg constraint_ok;           // high if all recommenders for this i are in subset or 0

  // Division temp signals
  reg [31:0] dividend;         // best_sum_p << 16
  reg [31:0] rema;             // remainder
  reg [31:0] quot;             // quotient (result)
  reg [31:0] shifted;          // dividend << 1 each cycle (or remaining bits)
  reg div_running;

  // Output latch control
  reg next_done;

  // Helper: find lowest set bit index (0..7). Assume sel != 0.
  function [3:0] lowest_set_bit;
    input [7:0] sel;
    casez (sel)
      8'bzzzzzzz1: lowest_set_bit = 4'd0;
      8'bzzzzzz10: lowest_set_bit = 4'd1;
      8'bzzzzz100: lowest_set_bit = 4'd2;
      8'bzzz1000: lowest_set_bit = 4'd3;
      8'bzz10000: lowest_set_bit = 4'd4;
      8'bz100000: lowest_set_bit = 4'd5;
      8'b1000000: lowest_set_bit = 4'd6;
      default     : lowest_set_bit = 4'd7; // 8'b10000000
    endcase
  endfunction

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      done       <= 1'b0;
      max_ratio  <= 32'b0;
      subset_idx <= 8'b0;
      subset_max <= 8'b0;
      div_cnt    <= 6'b0;
      best_sum_s <= 8'b0;
      best_sum_p <= 16'b0;
      prev_sum_s <= 8'b0;
      prev_sum_p <= 16'b0;
      next_sum_s <= 8'b0;
      next_sum_p <= 16'b0;
      prev_valid <= 1'b0;
      next_valid <= 1'b0;
      cur_k      <= 4'b0;
      cur_sum_p  <= 16'b0;
      cur_sum_s  <= 8'b0;
      cur_valid  <= 1'b0;
      i_emp      <= 3'b0;
      cur_mask   <= 8'b0;
      constraint_ok <= 1'b0;
      dividend   <= 32'b0;
      rema       <= 32'b0;
      quot       <= 32'b0;
      shifted    <= 32'b0;
      div_running <= 1'b0;
      next_done  <= 1'b0;
      lsb        <= 4'b0;
      delta_k    <= 3'b0;
      mask_bit   <= 1'b0;
      recommender <= 3'b0;
      rec_bit    <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          done       <= 1'b0;
          div_cnt    <= 6'b0;
          div_running <= 1'b0;
          next_done  <= 1'b0;
          if (start) begin
            subset_max <= (8'b1 << n) - 1;   // 2^n - 1
            subset_idx <= 8'b0;
            best_sum_s <= 8'b0;
            best_sum_p <= 16'b0;
            // Init pipeline to first subset (0)
            prev_sum_s <= 8'b0;
            prev_sum_p <= 16'b0;
            prev_valid <= 1'b1;              // subset 0 is trivially valid by size 0 and no recommenders
            next_sum_s <= s_arr[0];
            next_sum_p <= p_arr[0];
            lsb        <= lowest_set_bit(8'b1); // for subset 1, lsb=0
            delta_k    <= 3'b1;
            next_valid <= (k == 3'b1);       // size 1 subset valid if k==1
            state      <= ST_ITER;
          end else begin
            state      <= ST_IDLE;
          end
        end

        ST_ITER: begin
          // Current subset is whatever was computed in previous cycle
          cur_valid  <= prev_valid;
          cur_k      <= prev_sum_s[3:0] + prev_sum_s[7:4]; // popcount (sum of nibble bits)
          cur_sum_p  <= prev_sum_p;
          cur_sum_s  <= prev_sum_s;

          // Prepare next subset (subset_idx+1) by flipping lowest set bit of subset_idx
          if (subset_idx < subset_max) begin
            // Compute sums for next subset
            lsb        <= lowest_set_bit(subset_idx + 1);
            delta_k    <= ((subset_idx + 1) & (8'b1 << lsb)) ? 3'b1 : 3'b7; // +1 if adding, -1 if removing
            next_sum_s <= prev_sum_s + (delta_k[0] ? 8'd1 : 8'd255);
            next_sum_p <= prev_sum_p + (delta_k[0] ? p_arr[lsb] : ~p_arr[lsb] + 1);

            // Validate recommenders for next subset
            next_valid <= 1'b1;
            for (i_emp = 3'b0; i_emp < 3'd8; i_emp = i_emp + 3'b1) begin
              mask_bit     <= ( (subset_idx + 1) >> i_emp ) & 1'b1;
              recommender  <= r_arr[i_emp];
              rec_bit      <= ( (subset_idx + 1) >> recommender ) & 1'b1;
              // Constraint: if employee i is in subset and recommender != 0, recommender must be in subset
              constraint_ok <= ( (mask_bit & (|recommender)) ? rec_bit : 1'b1 );
              if (!constraint_ok) next_valid <= 1'b0;
            end

            // Check size and apply ratio update using cross-multiplication
            if (next_valid && (next_sum_s != 8'b0) && (next_sum_s[3:0] + next_sum_s[7:4] == k)) begin
              // Compare next_sum_p/next_sum_s vs best_sum_p/best_sum_s (cross-multiply)
              if ((best_sum_s == 8'b0) || ({16'b0, next_sum_p} * {8'b0, best_sum_s} > {16'b0, best_sum_p} * {8'b0, next_sum_s})) begin
                best_sum_s <= next_sum_s;
                best_sum_p <= next_sum_p;
              end
            end

            // Advance iterator
            subset_idx  <= subset_idx + 1;
            prev_sum_s  <= next_sum_s;
            prev_sum_p  <= next_sum_p;
            prev_valid  <= next_valid;
            state       <= ST_ITER;
          end else begin
            // Finished iterating; start division
            dividend    <= {best_sum_p, 16'b0}; // best_sum_p << 16
            rema        <= 32'b0;
            quot        <= 32'b0;
            div_cnt     <= 6'd0;
            shifted     <= {best_sum_p, 16'b0};
            div_running <= 1'b1;
            state       <= ST_DIV;
          end
        end

        ST_DIV: begin
          if (div_running) begin
            if (div_cnt < 6'd32) begin
              rema   <= {rema[30:0], shifted[31]};
              quot   <= {quot, 1'b0};
              if (rema >= {8'b0, best_sum_s}) begin
                rema   <= rema - {8'b0, best_sum_s};
                quot   <= quot + 1'b1;
              end
              shifted <= shifted << 1;
              div_cnt <= div_cnt + 1'b1;
              state   <= ST_DIV;
            end else begin
              // Division complete
              div_running <= 1'b0;
              state       <= ST_DONE;
            end
          end else begin
            state <= ST_DONE; // safety
          end
        end

        ST_DONE: begin
          max_ratio <= quot;
          done      <= 1'b1;
          next_done <= 1'b0;
          state     <= ST_IDLE; // Outputs held until next start pulse
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule