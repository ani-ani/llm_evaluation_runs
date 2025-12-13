module handsome_number_finder(
  input clk,
  input rst_n,
  input start,
  input [13:0] num_in,
  output reg [13:0] result1,
  output reg [13:0] result2,
  output reg valid,
  output reg tie_flag
);

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_SEARCH    = 3'd2,
    S_DONE      = 3'd3
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [13:0] base_num;
  reg [13:0] down_cur;
  reg [13:0] up_cur;
  reg [13:0] down_best;
  reg [13:0] up_best;
  reg        down_found;
  reg        up_found;
  reg [6:0]  iter_cnt; // to enforce < 100 cycles if desired

  // Function to check if a number is handsome
  function automatic is_handsome(input [13:0] n_in);
    reg [13:0] n;
    reg [3:0] d0, d1, d2, d3;
    reg [1:0] len;
    begin
      n = (n_in > 14'd9999) ? 14'd9999 : n_in;

      // Extract digits (0-9999)
      d0 = n % 10;
      d1 = (n / 10) % 10;
      d2 = (n / 100) % 10;
      d3 = (n / 1000) % 10;

      // Determine number of digits (treat n==0 as 1 digit)
      if (n >= 1000)
        len = 2'd4;
      else if (n >= 100)
        len = 2'd3;
      else if (n >= 10)
        len = 2'd2;
      else
        len = 2'd1;

      // Single-digit numbers are handsome
      if (len == 2'd1) begin
        is_handsome = 1'b1;
      end else begin
        // Check alternating parity for valid consecutive digits
        // Use only existing digits according to len
        is_handsome = 1'b1;
        if (len >= 2) begin
          if ((d0[0] == d1[0]))
            is_handsome = 1'b0;
        end
        if (is_handsome && len >= 3) begin
          if ((d1[0] == d2[0]))
            is_handsome = 1'b0;
        end
        if (is_handsome && len == 4) begin
          if ((d2[0] == d3[0]))
            is_handsome = 1'b0;
        end
      end
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_SEARCH;
      end

      S_SEARCH: begin
        // Transition to DONE when both directions found or iteration guard hit
        if ((down_found && up_found) || (iter_cnt >= 7'd99))
          next_state = S_DONE;
      end

      S_DONE: begin
        // Wait for next start
        if (start)
          next_state = S_INIT;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      base_num   <= 14'd0;
      down_cur   <= 14'd0;
      up_cur     <= 14'd0;
      down_best  <= 14'd0;
      up_best    <= 14'd0;
      down_found <= 1'b0;
      up_found   <= 1'b0;
      iter_cnt   <= 7'd0;
      result1    <= 14'd0;
      result2    <= 14'd0;
      valid      <= 1'b0;
      tie_flag   <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          valid      <= 1'b0;
          tie_flag   <= 1'b0;
          if (start) begin
            // Latch base number on start (saturate to 9999)
            base_num <= (num_in > 14'd9999) ? 14'd9999 : num_in;
          end
        end

        S_INIT: begin
          valid      <= 1'b0;
          tie_flag   <= 1'b0;
          down_found <= 1'b0;
          up_found   <= 1'b0;
          iter_cnt   <= 7'd0;

          // Initialize search bounds
          down_cur   <= (base_num == 14'd0) ? 14'd0 : base_num;
          up_cur     <= base_num;
        end

        S_SEARCH: begin
          valid    <= 1'b0;
          tie_flag <= 1'b0;

          // Increment iteration counter (for 100-cycle bound)
          if (iter_cnt < 7'd127)
            iter_cnt <= iter_cnt + 7'd1;

          // Search downward if not found yet
          if (!down_found) begin
            if (is_handsome(down_cur)) begin
              down_best  <= down_cur;
              down_found <= 1'b1;
            end else if (down_cur > 14'd0) begin
              down_cur <= down_cur - 14'd1;
            end else begin
              // Reached 0 and not handsome (only possible if we changed definition), mark as not found
              down_found <= 1'b1; // but no valid best; keep default
            end
          end

          // Search upward if not found yet
          if (!up_found) begin
            if (is_handsome(up_cur)) begin
              up_best  <= up_cur;
              up_found <= 1'b1;
            end else if (up_cur < 14'd9999) begin
              up_cur <= up_cur + 14'd1;
            end else begin
              // Reached max without finding
              up_found <= 1'b1;
            end
          end
        end

        S_DONE: begin
          // Compute final results once per entry into DONE
          // Use base_num latched earlier
          // Determine distances; if candidate missing, use max distance
          begin : settle_results
            reg [13:0] dist_down;
            reg [13:0] dist_up;
            reg        has_down;
            reg        has_up;

            has_down = down_found && is_handsome(down_best);
            has_up   = up_found   && is_handsome(up_best);

            dist_down = (has_down && (base_num >= down_best)) ? (base_num - down_best) : 14'h3FFF;
            dist_up   = (has_up   && (up_best   >= base_num)) ? (up_best   - base_num) : 14'h3FFF;

            if (has_down && (!has_up || (dist_down < dist_up))) begin
              result1  <= down_best;
              result2  <= 14'd0;
              tie_flag <= 1'b0;
            end else if (has_up && (!has_down || (dist_up < dist_down))) begin
              result1  <= up_best;
              result2  <= 14'd0;
              tie_flag <= 1'b0;
            end else if (has_down && has_up && (dist_down == dist_up)) begin
              if (down_best <= up_best) begin
                result1  <= down_best;
                result2  <= up_best;
              end else begin
                result1  <= up_best;
                result2  <= down_best;
              end
              tie_flag <= 1'b1;
            end else begin
              // Fallback: no valid (should not occur with given constraints)
              result1  <= 14'd0;
              result2  <= 14'd0;
              tie_flag <= 1'b0;
            end
          end

          valid <= 1'b1;

          // Allow retrigger on new start; re-init handled by next_state logic
          if (start) begin
            valid    <= 1'b0;
            tie_flag <= 1'b0;
            // base_num will be updated in S_IDLE on next cycle
          end
        end

        default: begin
          // Safe defaults
          valid    <= 1'b0;
          tie_flag <= 1'b0;
        end
      endcase
    end
  end

endmodule