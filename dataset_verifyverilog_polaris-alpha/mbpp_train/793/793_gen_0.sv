module last_position(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] target,
  input  [7:0][7:0] arr,
  output reg [2:0] position,
  output reg       found,
  output reg       done
);

  // State encoding
  localparam IDLE   = 2'b00;
  localparam SEARCH = 2'b01;
  localparam DONE_S = 2'b10;

  reg [1:0] state, next_state;

  reg [2:0] low, high, mid;
  reg [2:0] low_next, high_next, mid_next;
  reg [2:0] result_pos, result_pos_next;
  reg       search_found, search_found_next;

  // Sequential logic
  always @(posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      low          <= 3'd0;
      high         <= 3'd7;
      mid          <= 3'd0;
      result_pos   <= 3'd0;
      search_found <= 1'b0;
      position     <= 3'd0;
      found        <= 1'b0;
      done         <= 1'b0;
    end else begin
      state        <= next_state;
      low          <= low_next;
      high         <= high_next;
      mid          <= mid_next;
      result_pos   <= result_pos_next;
      search_found <= search_found_next;

      // Outputs are registered and valid when done is 1
      if (next_state == DONE_S) begin
        position <= result_pos_next;
        found    <= search_found_next;
        done     <= 1'b1;
      end else if (next_state == IDLE) begin
        // Clear done in IDLE
        done <= 1'b0;
      end
    end
  end

  // Combinational next-state and next-data logic
  always @* begin
    // Default assignments
    next_state        = state;
    low_next          = low;
    high_next         = high;
    mid_next          = mid;
    result_pos_next   = result_pos;
    search_found_next = search_found;

    case (state)
      IDLE: begin
        // Wait for start pulse
        if (start) begin
          // Initialize search bounds and results
          low_next          = 3'd0;
          high_next         = 3'd7;
          result_pos_next   = 3'd0;
          search_found_next = 1'b0;
          next_state        = SEARCH;
        end
      end

      SEARCH: begin
        if (low <= high) begin
          // Compute mid and evaluate this step in the same cycle
          mid_next = (low + high) >> 1;

          if (arr[mid_next] == target) begin
            // Record occurrence, move right to find last occurrence
            search_found_next = 1'b1;
            result_pos_next   = mid_next;
            low_next          = mid_next + 3'd1;
          end else if (arr[mid_next] < target) begin
            low_next = mid_next + 3'd1;
          end else begin
            high_next = (mid_next == 3'd0) ? 3'd0 : (mid_next - 3'd1);
          end

          // If next bounds are invalid, we are done next cycle
          if ( (mid_next >= low_next && mid_next <= high_next && low_next > high_next) ||
               (low_next > high_next) ) begin
            next_state = DONE_S;
          end
        end else begin
          // Search completed
          next_state = DONE_S;
        end
      end

      DONE_S: begin
        // Wait for start to return to IDLE, or auto-return when start deasserted
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule