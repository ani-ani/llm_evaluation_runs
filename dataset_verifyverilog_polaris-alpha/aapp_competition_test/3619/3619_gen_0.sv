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
  output reg done // high when result valid (1 cycle)
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam ENUM_PREP   = 3'd1;
  localparam ENUM_CHECK  = 3'd2;
  localparam ENUM_NEXT   = 3'd3;
  localparam DIV_PREP    = 3'd4;
  localparam DIV_RUN     = 3'd5;
  localparam DONE_STATE  = 3'd6;

  reg [2:0] state, next_state;

  // Subset enumeration
  reg [7:0] subset_mask;        // current subset mask
  reg [7:0] max_mask;           // limit mask = (1<<n) - 1

  // Current subset evaluation accumulators
  reg [3:0] count_sel;
  reg [31:0] sum_p;
  reg [31:0] sum_s;
  reg valid_subset;

  // Indices and temporaries
  reg [3:0] idx;
  reg [2:0] emp_idx;
  reg [2:0] rec_idx;
  reg member_bit;
  reg has_rec;

  // Best subset tracking
  reg [31:0] best_sum_p;
  reg [31:0] best_sum_s;
  reg        best_valid;

  // For comparison: sum_p/sum_s > best_sum_p/best_sum_s
  // Use 64-bit cross multiplication
  reg [63:0] lhs;
  reg [63:0] rhs;

  // Divider registers (non-restoring / restoring style unsigned 32/32, 32 cycles)
  reg [31:0] div_numer;
  reg [31:0] div_denom;
  reg [63:0] div_rem;
  reg [31:0] div_quot;
  reg [5:0]  div_cnt;

  // Combinational: next_state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = ENUM_PREP;
      end
      ENUM_PREP: begin
        next_state = ENUM_CHECK;
      end
      ENUM_CHECK: begin
        // After check/accum across all n indices, handled in sequential part
        // Transition decided when idx == n
        if (idx == n)
          next_state = ENUM_NEXT;
      end
      ENUM_NEXT: begin
        // If all subsets done, go to division; else back to ENUM_CHECK
        if (subset_mask == max_mask)
          next_state = (best_valid) ? DIV_PREP : DONE_STATE;
        else
          next_state = ENUM_CHECK;
      end
      DIV_PREP: begin
        next_state = (div_denom != 0) ? DIV_RUN : DONE_STATE;
      end
      DIV_RUN: begin
        if (div_cnt == 6'd32)
          next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // done asserted for one cycle, then wait for next start
        if (!start)
          next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      subset_mask <= 8'd0;
      max_mask    <= 8'd0;
      count_sel   <= 4'd0;
      sum_p       <= 32'd0;
      sum_s       <= 32'd0;
      valid_subset<= 1'b0;
      idx         <= 4'd0;
      best_sum_p  <= 32'd0;
      best_sum_s  <= 32'd0;
      best_valid  <= 1'b0;
      lhs         <= 64'd0;
      rhs         <= 64'd0;
      div_numer   <= 32'd0;
      div_denom   <= 32'd0;
      div_rem     <= 64'd0;
      div_quot    <= 32'd0;
      div_cnt     <= 6'd0;
      max_ratio   <= 32'd0;
      done        <= 1'b0;
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize best tracking
            best_sum_p  <= 32'd0;
            best_sum_s  <= 32'd0;
            best_valid  <= 1'b0;
            max_ratio   <= 32'd0;
            // Prepare subset enumeration
            subset_mask <= 8'd0; // start from 0, will increment in ENUM_NEXT
            max_mask    <= (n == 0) ? 8'd0 : ((8'd1 << n) - 1'b1);
          end
        end

        ENUM_PREP: begin
          // Begin with first subset (0) in ENUM_CHECK, accumulators cleared
          idx          <= 4'd0;
          count_sel    <= 4'd0;
          sum_p        <= 32'd0;
          sum_s        <= 32'd0;
          valid_subset <= 1'b1; // assume valid until proven otherwise
        end

        ENUM_CHECK: begin
          if (idx < n) begin
            emp_idx    = idx[2:0];
            member_bit = subset_mask[emp_idx];

            if (member_bit) begin
              // Count member
              count_sel <= count_sel + 4'd1;
              sum_p     <= sum_p + p_arr[emp_idx];
              sum_s     <= sum_s + s_arr[emp_idx];

              // Recommender check
              rec_idx = r_arr[emp_idx];
              if (rec_idx != 3'd0) begin
                // rec_idx is employee number 1-7; map to index rec_idx-1
                has_rec = subset_mask[rec_idx - 3'd1];
                if (!has_rec)
                  valid_subset <= 1'b0;
              end
            end

            idx <= idx + 4'd1;
          end
        end

        ENUM_NEXT: begin
          // At this point, idx == n, subset evaluated.
          // Validate size and non-zero denominator
          if (valid_subset && (count_sel == k) && (sum_s != 32'd0)) begin
            if (!best_valid) begin
              best_valid <= 1'b1;
              best_sum_p <= sum_p;
              best_sum_s <= sum_s;
            end else begin
              // Compare ratios via cross multiplication
              lhs = sum_p * best_sum_s; // current numerator * best denom
              rhs = best_sum_p * sum_s; // best numerator * current denom
              if (lhs > rhs) begin
                best_sum_p <= sum_p;
                best_sum_s <= sum_s;
              end
            end
          end

          // Move to next subset (unless already at max_mask)
          if (subset_mask != max_mask) begin
            subset_mask <= subset_mask + 8'd1;
            // prepare for next subset evaluation
            idx          <= 4'd0;
            count_sel    <= 4'd0;
            sum_p        <= 32'd0;
            sum_s        <= 32'd0;
            valid_subset <= 1'b1;
          end
        end

        DIV_PREP: begin
          // Prepare for fixed-point division: (best_sum_p << 16) / best_sum_s
          if (best_valid && (best_sum_s != 32'd0)) begin
            div_numer <= best_sum_p << 16;
            div_denom <= best_sum_s;
            div_rem   <= 64'd0;
            div_quot  <= 32'd0;
            div_cnt   <= 6'd0;
          end else begin
            // No valid subset: ratio = 0
            max_ratio <= 32'd0;
          end
        end

        DIV_RUN: begin
          // Iterative restoring division: 32 cycles
          if (div_cnt < 6'd32) begin
            // Shift left remainder and bring next numerator bit
            div_rem <= {div_rem[62:0], div_numer[31 - div_cnt]};

            // Trial subtract
            if (div_rem[63:32] >= div_denom) begin
              div_rem[63:32] <= div_rem[63:32] - div_denom;
              div_quot <= {div_quot[30:0], 1'b1};
            end else begin
              div_quot <= {div_quot[30:0], 1'b0};
            end

            div_cnt <= div_cnt + 6'd1;
          end

          if (div_cnt == 6'd32) begin
            // Division complete this cycle
            max_ratio <= div_quot;
          end
        end

        DONE_STATE: begin
          // Assert done for one cycle when entering this state
          done <= 1'b1;
          // Hold max_ratio, best_* until next start (handled by IDLE)
        end

        default: begin
          // Should not occur; keep safe defaults
        end
      endcase
    end
  end

endmodule