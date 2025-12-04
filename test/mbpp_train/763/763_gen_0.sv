module min_diff_finder(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] element_count,
  input  [7:0][7:0] array_in,
  output reg [7:0] min_diff,
  output reg done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam LOAD       = 3'd1;
  localparam SORT_OUTER = 3'd2;
  localparam SORT_INNER = 3'd3;
  localparam MIN_INIT   = 3'd4;
  localparam MIN_COMP   = 3'd5;
  localparam DONE_ST    = 3'd6;

  reg [2:0] state, next_state;

  // Internal registers
  reg [7:0] arr [0:7];
  reg [7:0] eff_count;         // effective element count (0-8)
  reg [2:0] outer_idx;         // bubble sort outer loop index (0-7)
  reg [2:0] inner_idx;         // bubble sort inner loop index (0-7)
  reg [7:0] current_min_diff;
  reg [2:0] diff_idx;          // index for min-diff comparison

  integer i;

  // Asynchronous reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      eff_count      <= 8'd0;
      outer_idx      <= 3'd0;
      inner_idx      <= 3'd0;
      diff_idx       <= 3'd0;
      current_min_diff <= 8'd0;
      min_diff       <= 8'd0;
      done           <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        arr[i] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
        end

        LOAD: begin
          // Latch effective count (limit to 8)
          if (element_count[7:3] != 0)
            eff_count <= 8'd8;
          else
            eff_count <= (element_count > 8'd8) ? 8'd8 : element_count;

          // Capture full array (only first eff_count used later)
          for (i = 0; i < 8; i = i + 1) begin
            arr[i] <= array_in[i];
          end

          done      <= 1'b0;
          min_diff  <= 8'd0;
          outer_idx <= 3'd0;
          inner_idx <= 3'd0;
          diff_idx  <= 3'd0;
        end

        SORT_OUTER: begin
          // Setup for each outer pass
          if (eff_count < 2) begin
            // Handled in next_state logic to jump to DONE_ST
          end else begin
            inner_idx <= 3'd0;
          end
        end

        SORT_INNER: begin
          if (eff_count >= 2) begin
            // Perform one bubble compare/swap per cycle
            if (inner_idx < eff_count - 1) begin
              if (arr[inner_idx] > arr[inner_idx + 1]) begin
                // swap
                {arr[inner_idx], arr[inner_idx + 1]} <= {arr[inner_idx + 1], arr[inner_idx]};
              end
              inner_idx <= inner_idx + 1'b1;
            end
          end
        end

        MIN_INIT: begin
          // Initialize min-diff computation after sorting
          if (eff_count < 2) begin
            current_min_diff <= 8'd0;
          end else begin
            current_min_diff <= 8'hFF; // large initial value
          end
          diff_idx <= 3'd0;
        end

        MIN_COMP: begin
          if (eff_count >= 2 && diff_idx < eff_count - 1) begin
            // Since sorted ascending, arr[diff_idx+1] >= arr[diff_idx]
            // difference fits in 8 bits
            if ((arr[diff_idx + 1] - arr[diff_idx]) < current_min_diff) begin
              current_min_diff <= (arr[diff_idx + 1] - arr[diff_idx]);
            end
            diff_idx <= diff_idx + 1'b1;
          end
        end

        DONE_ST: begin
          if (eff_count < 2)
            min_diff <= 8'd0;
          else
            min_diff <= current_min_diff;
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD;
        end
      end

      LOAD: begin
        // Move to sort or directly to done if <2 elements
        if ((element_count == 0) || (element_count == 1)) begin
          next_state = DONE_ST;
        end else begin
          next_state = SORT_OUTER;
        end
      end

      SORT_OUTER: begin
        if (eff_count < 2) begin
          next_state = DONE_ST;
        end else if (outer_idx >= eff_count - 1) begin
          // All passes done
          next_state = MIN_INIT;
        end else begin
          // Start inner loop for this outer pass
          next_state = SORT_INNER;
        end
      end

      SORT_INNER: begin
        if (eff_count < 2) begin
          next_state = DONE_ST;
        end else if (inner_idx >= eff_count - 1) begin
          // Finished one full inner pass; increment outer and go to next outer state
          next_state = SORT_OUTER;
        end else begin
          // Continue inner loop
          next_state = SORT_INNER;
        end
      end

      MIN_INIT: begin
        if (eff_count < 2)
          next_state = DONE_ST;
        else
          next_state = MIN_COMP;
      end

      MIN_COMP: begin
        if (eff_count < 2) begin
          next_state = DONE_ST;
        end else if (diff_idx >= eff_count - 1) begin
          next_state = DONE_ST;
        end else begin
          next_state = MIN_COMP;
        end
      end

      DONE_ST: begin
        // Wait for next start pulse to re-begin
        if (start)
          next_state = LOAD;
        else
          next_state = DONE_ST;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Outer loop index update separate to align with next_state transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outer_idx <= 3'd0;
    end else begin
      if (state == SORT_OUTER && eff_count >= 2) begin
        if (outer_idx < eff_count - 1)
          outer_idx <= outer_idx + 1'b1;
      end else if (state == LOAD || state == IDLE || state == MIN_INIT) begin
        outer_idx <= 3'd0;
      end
    end
  end

endmodule