module max_substring_rearrange(
  input clk,
  input rst_n,
  input start,
  input [15:0] s_in,
  input [4:0] s_len,
  input [15:0] t_in,
  input [4:0] t_len,
  output reg [15:0] result,
  output reg ready
);

  // FSM states
  localparam IDLE          = 3'd0;
  localparam COUNT         = 3'd1;
  localparam PREFIX_CALC   = 3'd2;
  localparam BUILD_RESULT  = 3'd3;
  localparam DONE          = 3'd4;

  reg [2:0] state, next_state;

  // Internal registers
  reg [4:0] s_zero_cnt, s_one_cnt;
  reg [4:0] t_zero_cnt, t_one_cnt;

  reg [4:0] idx;                 // generic index / substate counter

  // prefix function for t_in (max border length)
  reg [4:0] pi [0:15];
  reg [4:0] pi_val;              // temp for writing pi
  reg [4:0] k;                   // border length iterator

  reg [4:0] overlap_len;         // longest proper prefix == suffix for full t

  // Builder registers
  reg [4:0] rem_zero, rem_one;
  reg [4:0] out_pos;

  // Convenient wires for bits within active lengths
  wire s_bit = s_in[idx];
  wire t_bit = t_in[idx];

  // FSM next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COUNT;
      end
      COUNT: begin
        // After counting all bits
        if (idx == 5'd16)
          next_state = PREFIX_CALC;
      end
      PREFIX_CALC: begin
        // We use idx to iterate i from 1 to t_len-1
        if (idx >= t_len)
          next_state = BUILD_RESULT;
      end
      BUILD_RESULT: begin
        // Exit when out_pos reaches 16 or no bits remain to place
        if ((out_pos == 5'd16) || (rem_zero == 0 && rem_one == 0))
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i_int;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      ready      <= 1'b0;
      result     <= 16'b0;
      s_zero_cnt <= 5'd0;
      s_one_cnt  <= 5'd0;
      t_zero_cnt <= 5'd0;
      t_one_cnt  <= 5'd0;
      idx        <= 5'd0;
      k          <= 5'd0;
      overlap_len<= 5'd0;
      rem_zero   <= 5'd0;
      rem_one    <= 5'd0;
      out_pos    <= 5'd0;
      for (i_int = 0; i_int < 16; i_int = i_int + 1)
        pi[i_int] <= 5'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          ready      <= 1'b0;
          result     <= 16'b0;
          s_zero_cnt <= 5'd0;
          s_one_cnt  <= 5'd0;
          t_zero_cnt <= 5'd0;
          t_one_cnt  <= 5'd0;
          idx        <= 5'd0;
          k          <= 5'd0;
          overlap_len<= 5'd0;
          out_pos    <= 5'd0;
          rem_zero   <= 5'd0;
          rem_one    <= 5'd0;
          // pi array implicitly reset previously; no changes here
        end

        COUNT: begin
          // Count bits in s_in according to s_len (left-aligned)
          // and bits in t_in according to t_len (left-aligned)
          // We iterate idx from 0 to 15 and gate by length.

          // s_in counting
          if (idx < s_len) begin
            if (s_in[idx])
              s_one_cnt <= s_one_cnt + 1'b1;
            else
              s_zero_cnt <= s_zero_cnt + 1'b1;
          end

          // t_in counting
          if (idx < t_len) begin
            if (t_in[idx])
              t_one_cnt <= t_one_cnt + 1'b1;
            else
              t_zero_cnt <= t_zero_cnt + 1'b1;
          end

          // advance idx; when reaches 16, FSM moves to PREFIX_CALC next
          idx <= idx + 1'b1;
        end

        PREFIX_CALC: begin
          // Compute prefix-function (pi) for t_in[0 .. t_len-1]
          // Standard KMP prefix function, sequentialized.
          // Conventions: pi[0] = 0 already. idx is current i.

          if (idx == 0) begin
            // initialize for i = 1
            pi[0] <= 5'd0;
            idx   <= 5'd1;
            k     <= 5'd0;
          end else if (idx < t_len) begin
            // process position idx
            if (k > 0 && t_in[idx] != t_in[k]) begin
              k <= pi[k-1];
            end else if (t_in[idx] == t_in[k] && k + 1 < t_len) begin
              k       <= k + 1'b1;
              pi[idx] <= k + 1'b1; // temporary; may be overwritten in next cycles via k updates
              idx     <= idx + 1'b1;
            end else if (t_in[idx] == t_in[k] && k + 1 == t_len) begin
              // if extension equals full length, keep proper prefix only
              pi[idx] <= k; // border cannot be full length; keep prior k
              idx     <= idx + 1'b1;
            end else begin
              // k == 0 and mismatch or no extension
              pi[idx] <= 5'd0;
              idx     <= idx + 1'b1;
            end
          end else begin
            // done computing pi; derive overlap_len from pi[t_len-1]
            overlap_len <= (t_len > 0) ? pi[t_len-1] : 5'd0;
            // prepare for build phase
            // compute remaining counts from s_in counts
            // We'll decide in BUILD_RESULT if we can place first full t
            rem_zero <= s_zero_cnt;
            rem_one  <= s_one_cnt;
            out_pos  <= 5'd0;
          end
        end

        BUILD_RESULT: begin
          // Build result stepwise, preserving counts and maximizing t occurrences.
          // Priority:
          // 1) Place one full t if possible
          // 2) Then repeatedly place overlap suffix blocks
          // 3) Finally, remaining zeros then ones

          // Local, combinational-style decisions in sequential process.

          // Helper: can place full t
          if (out_pos == 0) begin
            // first, try full t
            if (rem_zero >= t_zero_cnt && rem_one >= t_one_cnt && t_len != 0) begin
              // append full t one bit per cycle
              if (idx < t_len && out_pos < 16) begin
                // write bit
                result[out_pos] <= t_in[idx];
                // consume counts
                if (t_in[idx]) rem_one <= rem_one - 1'b1;
                else           rem_zero <= rem_zero - 1'b1;
                out_pos <= out_pos + 1'b1;
                idx     <= idx + 1'b1;
              end else begin
                // finished full t, init for overlap blocks
                idx <= overlap_len; // next suffix start index
              end
            end else begin
              // cannot place any t; fall back directly to zeros then ones
              if (rem_zero != 0 && out_pos < 16) begin
                result[out_pos] <= 1'b0;
                rem_zero        <= rem_zero - 1'b1;
                out_pos         <= out_pos + 1'b1;
              end else if (rem_one != 0 && out_pos < 16) begin
                result[out_pos] <= 1'b1;
                rem_one         <= rem_one - 1'b1;
                out_pos         <= out_pos + 1'b1;
              end
            end
          end else begin
            // After first t placement attempt
            // Try to place repeated overlap-suffix based extensions
            if (idx < t_len && overlap_len < t_len && out_pos < 16) begin
              // Next char from t based on overlap suffix
              // Need to ensure remaining counts allow this bit
              if (t_in[idx] == 1'b0) begin
                if (rem_zero != 0) begin
                  result[out_pos] <= 1'b0;
                  rem_zero        <= rem_zero - 1'b1;
                  out_pos         <= out_pos + 1'b1;
                  idx             <= idx + 1'b1;
                end else begin
                  // cannot continue pattern; go to fill remainder
                  idx <= t_len; // force to remainder section
                end
              end else begin
                if (rem_one != 0) begin
                  result[out_pos] <= 1'b1;
                  rem_one         <= rem_one - 1'b1;
                  out_pos         <= out_pos + 1'b1;
                  idx             <= idx + 1'b1;
                end else begin
                  // cannot continue pattern; go to fill remainder
                  idx <= t_len;
                end
              end
            end else if (idx >= t_len && overlap_len != 0 && out_pos < 16) begin
              // Finished one overlapped copy; attempt another by restarting from overlap_len
              // But only if we can still realize a full suffix-based extension.
              // We'll tentatively try; actual ability enforced by bit-level count checks above.
              idx <= overlap_len;
            end else begin
              // Either no overlap pattern or cannot continue; fill remaining bits.
              if (rem_zero != 0 && out_pos < 16) begin
                result[out_pos] <= 1'b0;
                rem_zero        <= rem_zero - 1'b1;
                out_pos         <= out_pos + 1'b1;
              end else if (rem_one != 0 && out_pos < 16) begin
                result[out_pos] <= 1'b1;
                rem_one         <= rem_one - 1'b1;
                out_pos         <= out_pos + 1'b1;
              end
            end
          end
        end

        DONE: begin
          // Pad remaining bits with zeros
          if (!ready) begin
            for (i_int = out_pos; i_int < 16; i_int = i_int + 1)
              result[i_int] <= 1'b0;
            ready <= 1'b1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule