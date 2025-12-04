module max_non_square(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start signal
  input signed [15:0] arr [0:7], // 8x16-bit signed array
  output reg signed [15:0] result, // max non-square found
  output reg done // high when result valid
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    COMPARE= 2'b01,
    DONE   = 2'b10
  } state_t;

  state_t state, next_state;

  // Index for array elements
  reg [2:0] idx;

  // Maximum non-square tracker
  reg signed [15:0] max_non_sq;
  reg has_candidate;

  // Latched result (to output at DONE)
  reg signed [15:0] result_next;

  // Combinational check for perfect square (0..255) using <= 16 comparators
  function automatic logic is_perfect_square_0_255(input logic [15:0] x);
    logic [7:0] ux;
    begin
      ux = x[7:0];
      // Check membership in the set of perfect squares up to 15^2=225
      is_perfect_square_0_255 =
           (ux == 8'd0  ) || (ux == 8'd1  ) || (ux == 8'd4  ) || (ux == 8'd9  ) ||
           (ux == 8'd16 ) || (ux == 8'd25 ) || (ux == 8'd36 ) || (ux == 8'd49 ) ||
           (ux == 8'd64 ) || (ux == 8'd81 ) || (ux == 8'd100) || (ux == 8'd121) ||
           (ux == 8'd144) || (ux == 8'd169) || (ux == 8'd196) || (ux == 8'd225);
    end
  endfunction

  // Wrapper: perfect square for non-negative 16-bit values
  function automatic logic is_perfect_square(input signed [15:0] val);
    logic [15:0] uval;
    begin
      // Only consider 0..255 as potential perfect squares (fits requirement and limits logic).
      if (val < 0)
        is_perfect_square = 1'b0;
      else begin
        uval = val[15:0];
        if (uval <= 16'd255)
          is_perfect_square = is_perfect_square_0_255(uval);
        else
          is_perfect_square = 1'b0;
      end
    end
  endfunction

  // Next-state and combinational control logic
  always @* begin
    next_state   = state;
    result_next  = result;

    case (state)
      IDLE: begin
        if (start)
          next_state = COMPARE;
      end

      COMPARE: begin
        if (idx == 3'd7)
          next_state = DONE;
      end

      DONE: begin
        // Stay in DONE until next start; result held stable
        if (start)
          next_state = COMPARE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      idx           <= 3'd0;
      max_non_sq    <= 16'sh8000; // Minimum 16-bit signed value
      has_candidate <= 1'b0;
      result        <= 16'sd0;
      done          <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            idx           <= 3'd0;
            max_non_sq    <= 16'sh8000;
            has_candidate <= 1'b0;
          end
        end

        COMPARE: begin
          // Fetch current value
          reg signed [15:0] cur;
          reg is_non_square;
          cur = arr[idx];

          // Determine if current value is non-square
          if (cur < 0)
            is_non_square = 1'b1;
          else
            is_non_square = ~is_perfect_square(cur);

          // Update max_non_sq if qualified
          if (is_non_square) begin
            if (!has_candidate || (cur > max_non_sq)) begin
              max_non_sq    <= cur;
              has_candidate <= 1'b1;
            end
          end

          // Increment index
          idx <= idx + 3'd1;

          // On last comparison, prepare result for next cycle (DONE)
          if (idx == 3'd7) begin
            if (has_candidate || is_non_square)
              result <= (is_non_square && (!has_candidate || (cur > max_non_sq))) ? cur : max_non_sq;
            else
              result <= 16'sd0; // If no non-square found, define result as 0
          end

          done <= 1'b0;
        end

        DONE: begin
          // Result is stable; assert done
          done <= 1'b1;
          if (start) begin
            // Prepare for new run on next cycle
            idx           <= 3'd0;
            max_non_sq    <= 16'sh8000;
            has_candidate <= 1'b0;
            done          <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule