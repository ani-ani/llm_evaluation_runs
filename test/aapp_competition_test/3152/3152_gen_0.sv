module consecutive_subsequence_cost(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] element_0,
  input [7:0] element_1,
  input [7:0] element_2,
  input [7:0] element_3,
  input [7:0] element_4,
  input [7:0] element_5,
  input [7:0] element_6,
  input [7:0] element_7,
  output reg [29:0] result,
  output reg done
);

  // Parameters
  localparam MOD_VAL = 30'd1000000000;

  // State encoding
  localparam IDLE            = 2'b00;
  localparam COMPUTE_MIN_MAX = 2'b01;
  localparam ACCUMULATE      = 2'b10;
  localparam FINISH          = 2'b11;

  reg [1:0] state, next_state;

  // Indices
  reg [2:0] start_idx;
  reg [2:0] end_idx;

  // Current subsequence properties
  reg [7:0] cur_min;
  reg [7:0] cur_max;
  reg [3:0] cur_len; // up to 8

  // Accumulator (needs to hold up to about 30 bits, use extra safety bits)
  reg [35:0] sum_reg;

  // Product signals
  reg [15:0] mm_prod;       // min * max <= 255 * 255
  reg [19:0] term;          // mm_prod * length <= 65025 * 8
  reg [35:0] sum_next;

  // Element read mux
  wire [7:0] cur_element;
  assign cur_element = (end_idx == 3'd0) ? element_0 :
                       (end_idx == 3'd1) ? element_1 :
                       (end_idx == 3'd2) ? element_2 :
                       (end_idx == 3'd3) ? element_3 :
                       (end_idx == 3'd4) ? element_4 :
                       (end_idx == 3'd5) ? element_5 :
                       (end_idx == 3'd6) ? element_6 :
                                           element_7;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      start_idx <= 3'd0;
      end_idx   <= 3'd0;
      cur_min   <= 8'd0;
      cur_max   <= 8'd0;
      cur_len   <= 4'd0;
      sum_reg   <= 36'd0;
      result    <= 30'd0;
      done      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for first subsequence start = 0, end = 0
            start_idx <= 3'd0;
            end_idx   <= 3'd0;
            cur_min   <= element_0;
            cur_max   <= element_0;
            cur_len   <= 4'd1;
            sum_reg   <= 36'd0;
          end
        end

        COMPUTE_MIN_MAX: begin
          // Update min, max, length using current end_idx element
          // For a new start, this state is entered with end_idx already set.
          if (end_idx == start_idx) begin
            // First element of this subsequence
            cur_min <= cur_element;
            cur_max <= cur_element;
            cur_len <= 4'd1;
          end else begin
            // Extend subsequence
            cur_min <= (cur_element < cur_min) ? cur_element : cur_min;
            cur_max <= (cur_element > cur_max) ? cur_element : cur_max;
            cur_len <= cur_len + 4'd1;
          end
        end

        ACCUMULATE: begin
          // Perform accumulation with modulo
          sum_reg <= sum_next;

          // Decide next indices
          if (end_idx + 3'd1 < N) begin
            // Move to next end index for same start
            end_idx <= end_idx + 3'd1;
          end else begin
            // Completed all end indices for this start
            if (start_idx + 3'd1 < N) begin
              // Move to next start, reset end and subseq stats
              start_idx <= start_idx + 3'd1;
              end_idx   <= start_idx + 3'd1; // will be corrected in COMPUTE_MIN_MAX
              // cur_min/cur_max/cur_len re-initialized in COMPUTE_MIN_MAX on next cycle
            end
          end
        end

        FINISH: begin
          // Latch final result and signal done
          result <= sum_reg[29:0];
          done   <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Combinational: next_state and accumulation logic
  always @(*) begin
    next_state = state;
    mm_prod    = 16'd0;
    term       = 20'd0;
    sum_next   = sum_reg;

    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE_MIN_MAX;
      end

      COMPUTE_MIN_MAX: begin
        // move to ACCUMULATE to compute term with updated cur_min, cur_max, cur_len
        next_state = ACCUMULATE;

        // Note: actual mm_prod/term/sum_next computed in ACCUMULATE state
      end

      ACCUMULATE: begin
        // Compute min*max*length from registered cur_min/cur_max/cur_len
        mm_prod  = cur_min * cur_max;
        term     = mm_prod * cur_len;
        sum_next = sum_reg + term;

        // Apply modulo 1e9
        if (sum_next >= MOD_VAL)
          sum_next = sum_next - MOD_VAL;

        // Determine whether to continue or finish
        if (end_idx + 3'd1 < N) begin
          // More subsequences for current start: go compute next min/max
          next_state = COMPUTE_MIN_MAX;
        end else begin
          if (start_idx + 3'd1 < N) begin
            // Next start index available
            next_state = COMPUTE_MIN_MAX;
          end else begin
            // All subsequences processed
            next_state = FINISH;
          end
        end
      end

      FINISH: begin
        // Wait in FINISH until new start; then reinitialize via IDLE->start
        if (start)
          next_state = COMPUTE_MIN_MAX;
        else
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule