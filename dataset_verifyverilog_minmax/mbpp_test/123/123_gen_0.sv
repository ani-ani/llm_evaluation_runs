module amicable_sum (
  input  clk,
  input  rst_n,
  input  start,
  input  [15:0] limit,
  output reg [15:0] sum,
  output reg done
);
  // State machine states
  localparam S_IDLE          = 3'd0;
  localparam S_ADD_DIV       = 3'd1;
  localparam S_CHECK_amic    = 3'd2;
  localparam S_MARK_FOUND    = 3'd3;
  localparam S_INC_I         = 3'd4;
  localparam S_DONE          = 3'd5;

  reg [15:0] i;            // current number under test
  reg [15:0] d;            // divisor candidate
  reg [31:0] sum1;         // running sum of proper divisors of i
  reg [31:0] sum2;         // running sum of proper divisors of sum1 (when needed)
  reg [15:0] amic_b;       // candidate b such that (a,b) might be amicable (a = i)
  reg [2:0]  state;
  reg [15:0] limit_r;      // registered limit
  reg       hold_i;
  reg       hold_b;
  reg [15:0] hold_i_val;
  reg [15:0] hold_b_val;
  reg [15:0] pending_a;    // first of a pair awaiting second's turn to add sum
  reg [15:0] pending_b;    // second of a pair awaiting first's turn to add sum
  reg       pending_valid; // pending pair awaiting second number to be processed

  // Found pairs tracking: bit j is set when number j is used in an amicable pair already counted.
  // Width sized to largest possible sum-of-divisors value we may encounter (16-bit limit -> at most 2*limit).
  reg [65535:0] found; // synthesis attribute keep of found is true

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      sum          <= 16'd0;
      done         <= 1'b0;
      i            <= 16'd0;
      d            <= 16'd0;
      sum1         <= 32'd0;
      sum2         <= 32'd0;
      amic_b       <= 16'd0;
      limit_r      <= 16'd0;
      hold_i       <= 1'b0;
      hold_b       <= 1'b0;
      hold_i_val   <= 16'd0;
      hold_b_val   <= 16'd0;
      pending_a    <= 16'd0;
      pending_b    <= 16'd0;
      pending_valid<= 1'b0;
      found        <= 65536'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            sum          <= 16'd0;
            i            <= 16'd2;
            d            <= 16'd1;
            sum1         <= 32'd0;
            sum2         <= 32'd0;
            amic_b       <= 16'd0;
            limit_r      <= limit;
            hold_i       <= 1'b0;
            hold_b       <= 1'b0;
            hold_i_val   <= 16'd0;
            hold_b_val   <= 16'd0;
            pending_a    <= 16'd0;
            pending_b    <= 16'd0;
            pending_valid<= 1'b0;
            found        <= 65536'd0;
            state        <= S_ADD_DIV;
          end else begin
            state <= S_IDLE;
          end
        end

        // Accumulate sum of proper divisors of i using sequential divisor summation
        S_ADD_DIV: begin
          if (d > (i >> 1)) begin
            state <= S_CHECK_amic;
          end else begin
            sum1 <= sum1 + ( (i % d) == 0 ? d : 0 );
            d    <= d + 1;
          end
        end

        // Check amicable conditions and potentially store a pair for later addition
        S_CHECK_amic: begin
          amic_b <= sum1[15:0];
          if (sum1 > i && sum1 <= 16'hFFFF) begin
            if (sum1 <= limit_r) begin
              // We will compute sum2 for sum1, which is within range [2, limit]
              d    <= 16'd1;
              sum2 <= 32'd0;
              state <= S_MARK_FOUND; // will compute sum2 for sum1 in this same state
            end else begin
              // sum1 is outside the limit: we cannot mark found bits; add i now if amicable with sum1
              if (sum1 <= 16'hFFFF) begin
                // compute sum2 for sum1 anyway (since sum1 may still be amicable with i)
                d    <= 16'd1;
                sum2 <= 32'd0;
                state <= S_MARK_FOUND;
              end else begin
                // sum1 too large to compute safely; treat as non-amicable
                state <= S_INC_I;
              end
            end
          end else begin
            state <= S_INC_I;
          end
        end

        // Compute sum2 (sum of proper divisors of amic_b/sum1) if needed and decide if amicable.
        // If amicable, add to sum and queue a mark request for the next iteration.
        S_MARK_FOUND: begin
          if (d > (amic_b >> 1)) begin
            if (sum2 == i) begin
              // Amicable pair found: (i, amic_b)
              // Queue addition now if both within 16-bit range to avoid overflow
              if (i + amic_b <= 16'hFFFF) begin
                sum <= sum + i + amic_b;
              end else begin
                // Overflow on sum: saturate at 16-bit max
                sum <= 16'hFFFF;
              end
              // Queue mark request to mark both numbers as found in the next number's turn
              hold_i     <= 1'b1;
              hold_b     <= (amic_b <= 16'hFFFF);
              hold_i_val <= i;
              hold_b_val <= amic_b[15:0];
            end
            state <= S_INC_I;
          end else begin
            sum2 <= sum2 + ( (amic_b % d) == 0 ? d : 0 );
            d    <= d + 1;
          end
        end

        S_INC_I: begin
          // Apply pending mark for a previously confirmed amicable pair (both numbers now in range)
          if (hold_i) begin
            if (hold_b) begin
              found[hold_b_val] <= 1'b1;
              found[hold_i_val] <= 1'b1;
            end else begin
              found[hold_i_val] <= 1'b1;
            end
            hold_i <= 1'b0;
            hold_b <= 1'b0;
          end

          if (i >= limit_r) begin
            state <= S_DONE;
            done  <= 1'b1;
          end else begin
            i    <= i + 1;
            d    <= 16'd1;
            sum1 <= 32'd0;
            sum2 <= 32'd0;
            state<= S_ADD_DIV;
          end
        end

        S_DONE: begin
          done  <= 1'b1;
          state <= S_IDLE; // auto-return to idle; can be restarted via start
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule