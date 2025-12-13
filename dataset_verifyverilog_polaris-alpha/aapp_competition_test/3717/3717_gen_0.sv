module rectangle_overlap_point(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Number of rectangles (3 bits, max 8)
  input [31:0] rect_x1 [0:7], // x1 coordinates (32-bit signed)
  input [31:0] rect_y1 [0:7], // y1 coordinates (32-bit signed)
  input [31:0] rect_x2 [0:7], // x2 coordinates (32-bit signed)
  input [31:0] rect_y2 [0:7], // y2 coordinates (32-bit signed)
  output reg [31:0] point_x, // Found x coordinate
  output reg [31:0] point_y, // Found y coordinate
  output reg done // High when computation completes
);

  // Internal registers
  reg [2:0] idx;
  reg [2:0] best_i;
  reg       found;

  // First pass aggregates
  reg [31:0] max_x1_val, max_x1_2nd;
  reg [2:0]  max_x1_idx;

  reg [31:0] max_y1_val, max_y1_2nd;
  reg [2:0]  max_y1_idx;

  reg [31:0] min_x2_val, min_x2_2nd;
  reg [2:0]  min_x2_idx;

  reg [31:0] min_y2_val, min_y2_2nd;
  reg [2:0]  min_y2_idx;

  // FSM state
  typedef enum logic [1:0] {
    S_IDLE   = 2'b00,
    S_PASS1  = 2'b01,
    S_PASS2  = 2'b10,
    S_DONE   = 2'b11
  } state_t;

  state_t state, next_state;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_PASS1;
      end
      S_PASS1: begin
        if (idx == (n - 1)) next_state = S_PASS2;
      end
      S_PASS2: begin
        if (idx == (n - 1) || found) next_state = S_DONE;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      idx         <= 3'd0;
      best_i      <= 3'd0;
      found       <= 1'b0;
      done        <= 1'b0;
      point_x     <= 32'sd0;
      point_y     <= 32'sd0;
      max_x1_val  <= 32'sd0;
      max_x1_2nd  <= 32'sd0;
      max_x1_idx  <= 3'd0;
      max_y1_val  <= 32'sd0;
      max_y1_2nd  <= 32'sd0;
      max_y1_idx  <= 3'd0;
      min_x2_val  <= 32'sd0;
      min_x2_2nd  <= 32'sd0;
      min_x2_idx  <= 3'd0;
      min_y2_val  <= 32'sd0;
      min_y2_2nd  <= 32'sd0;
      min_y2_idx  <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        // Idle: wait for start, clear outputs
        S_IDLE: begin
          done   <= 1'b0;
          found  <= 1'b0;
          idx    <= 3'd0;

          if (start) begin
            // Initialize first-pass aggregates using rect[0]
            // Assumes n >= 1
            max_x1_val <= rect_x1[0];
            max_x1_2nd <= 32'sh8000_0000; // very small
            max_x1_idx <= 3'd0;

            max_y1_val <= rect_y1[0];
            max_y1_2nd <= 32'sh8000_0000;
            max_y1_idx <= 3'd0;

            min_x2_val <= rect_x2[0];
            min_x2_2nd <= 32'sh7FFF_FFFF; // very large
            min_x2_idx <= 3'd0;

            min_y2_val <= rect_y2[0];
            min_y2_2nd <= 32'sh7FFF_FFFF;
            min_y2_idx <= 3'd0;

            idx        <= 3'd1;
            best_i     <= 3'd0;
          end
        end

        // PASS1: compute global max/min and second max/min with indices
        S_PASS1: begin
          if (idx < n) begin
            // Update max_x1 and second max_x1
            if ($signed(rect_x1[idx]) > $signed(max_x1_val)) begin
              max_x1_2nd <= max_x1_val;
              max_x1_val <= rect_x1[idx];
              max_x1_idx <= idx;
            end else if ($signed(rect_x1[idx]) > $signed(max_x1_2nd)) begin
              max_x1_2nd <= rect_x1[idx];
            end

            // Update max_y1 and second max_y1
            if ($signed(rect_y1[idx]) > $signed(max_y1_val)) begin
              max_y1_2nd <= max_y1_val;
              max_y1_val <= rect_y1[idx];
              max_y1_idx <= idx;
            end else if ($signed(rect_y1[idx]) > $signed(max_y1_2nd)) begin
              max_y1_2nd <= rect_y1[idx];
            end

            // Update min_x2 and second min_x2
            if ($signed(rect_x2[idx]) < $signed(min_x2_val)) begin
              min_x2_2nd <= min_x2_val;
              min_x2_val <= rect_x2[idx];
              min_x2_idx <= idx;
            end else if ($signed(rect_x2[idx]) < $signed(min_x2_2nd)) begin
              min_x2_2nd <= rect_x2[idx];
            end

            // Update min_y2 and second min_y2
            if ($signed(rect_y2[idx]) < $signed(min_y2_val)) begin
              min_y2_2nd <= min_y2_val;
              min_y2_val <= rect_y2[idx];
              min_y2_idx <= idx;
            end else if ($signed(rect_y2[idx]) < $signed(min_y2_2nd)) begin
              min_y2_2nd <= rect_y2[idx];
            end

            idx <= idx + 3'd1;
          end
        end

        // PASS2: for each i, compute excluded aggregates and test
        S_PASS2: begin
          if (!found && idx < n) begin
            // Compute excluded max_x1
            reg [31:0] ex_max_x1;
            reg [31:0] ex_max_y1;
            reg [31:0] ex_min_x2;
            reg [31:0] ex_min_y2;

            if (idx == max_x1_idx)
              ex_max_x1 = max_x1_2nd;
            else
              ex_max_x1 = max_x1_val;

            if (idx == max_y1_idx)
              ex_max_y1 = max_y1_2nd;
            else
              ex_max_y1 = max_y1_val;

            if (idx == min_x2_idx)
              ex_min_x2 = min_x2_2nd;
            else
              ex_min_x2 = min_x2_val;

            if (idx == min_y2_idx)
              ex_min_y2 = min_y2_2nd;
            else
              ex_min_y2 = min_y2_val;

            // Check condition: intersection of all except i is non-empty
            if (($signed(ex_max_x1) <= $signed(ex_min_x2)) &&
                ($signed(ex_max_y1) <= $signed(ex_min_y2))) begin
              found   <= 1'b1;
              best_i  <= idx;
              point_x <= ex_max_x1;
              point_y <= ex_max_y1;
            end

            idx <= idx + 3'd1;
          end
        end

        // DONE: signal completion; hold result until start deasserts
        S_DONE: begin
          done <= 1'b1;
          // point_x, point_y, found, best_i held from PASS2
          if (!start) begin
            // Ready for next transaction on leaving DONE via next_state
          end
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule