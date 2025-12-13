module rectangle_intersect(
  input clk,
  input rst_n,
  input load,
  input start,
  input [15:0] x1,
  input [15:0] y1,
  input [15:0] x2,
  input [15:0] y2,
  output reg result,
  output reg done
);

  // Storage for up to 8 rectangles
  reg [15:0] rect_x1 [0:7];
  reg [15:0] rect_y1 [0:7];
  reg [15:0] rect_x2 [0:7];
  reg [15:0] rect_y2 [0:7];

  reg [3:0] rect_count; // 0..8

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD_S = 2'b01,
    CHECK = 2'b10,
    DONE = 2'b11
  } state_t;

  state_t state, next_state;

  // Pair indices
  reg [2:0] i_idx;
  reg [2:0] j_idx;

  // Internal signals
  reg start_pend;          // latch start pulse to initiate computation
  reg intersect_found;

  // Rectangle intersection check (combinational for current pair)
  wire [15:0] ax1 = rect_x1[i_idx];
  wire [15:0] ay1 = rect_y1[i_idx];
  wire [15:0] ax2 = rect_x2[i_idx];
  wire [15:0] ay2 = rect_y2[i_idx];

  wire [15:0] bx1 = rect_x1[j_idx];
  wire [15:0] by1 = rect_y1[j_idx];
  wire [15:0] bx2 = rect_x2[j_idx];
  wire [15:0] by2 = rect_y2[j_idx];

  wire no_intersect = (ax2 <= bx1) || (bx2 <= ax1) || (ay2 <= by1) || (by2 <= ay1);
  wire pair_intersect = ~no_intersect;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rect_count <= 4'd0;
      state <= IDLE;
      result <= 1'b0;
      done <= 1'b0;
      i_idx <= 3'd0;
      j_idx <= 3'd1;
      start_pend <= 1'b0;
      intersect_found <= 1'b0;
    end else begin
      state <= next_state;

      // Load rectangles
      if (state == IDLE || state == LOAD_S) begin
        if (load && (rect_count < 4'd8)) begin
          rect_x1[rect_count] <= x1;
          rect_y1[rect_count] <= y1;
          rect_x2[rect_count] <= x2;
          rect_y2[rect_count] <= y2;
          rect_count <= rect_count + 4'd1;
        end
      end

      // Latch start when in IDLE/LOAD_S state
      if ((state == IDLE || state == LOAD_S) && start) begin
        start_pend <= 1'b1;
      end

      // Control behavior per state
      case (state)
        IDLE: begin
          done <= 1'b0;
          // result held until next computation, per spec
          if (!start && !load) begin
            // no-op
          end
        end

        LOAD_S: begin
          done <= 1'b0;
        end

        CHECK: begin
          done <= 1'b0;
          // Evaluate current pair
          if (!intersect_found && pair_intersect) begin
            intersect_found <= 1'b1;
            result <= 1'b1;
          end

          // Advance pair indices only if no intersection found yet
          if (!intersect_found) begin
            if (j_idx + 3'd1 < rect_count) begin
              j_idx <= j_idx + 3'd1;
            end else begin
              if (i_idx + 3'd1 < rect_count - 1) begin
                i_idx <= i_idx + 3'd1;
                j_idx <= i_idx + 3'd2;
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Reset control signals for next run when leaving DONE
          start_pend <= 1'b0;
          intersect_found <= intersect_found; // hold
        end

        default: begin
          // should not occur
        end
      endcase

      // When transitioning into CHECK state, initialize indices and status
      if (state != CHECK && next_state == CHECK) begin
        i_idx <= 3'd0;
        j_idx <= (rect_count > 1) ? 3'd1 : 3'd0;
        intersect_found <= 1'b0;
        // Default result to 0 before checking
        result <= 1'b0;
      end

      // When transitioning into IDLE from DONE, allow new loads, but preserve result
      if (state == DONE && next_state == IDLE) begin
        done <= 1'b0;
      end

      // Clear rectangles and counters only on reset; preserve across runs
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (load)
          next_state = LOAD_S;
        else if (start_pend || start) begin
          // If no or only one rectangle, complete immediately
          if (rect_count < 2) begin
            next_state = DONE;
          end else begin
            next_state = CHECK;
          end
        end
      end

      LOAD_S: begin
        if (start_pend || start) begin
          if (rect_count < 2)
            next_state = DONE;
          else
            next_state = CHECK;
        end else if (!load) begin
          next_state = IDLE;
        end
      end

      CHECK: begin
        if (intersect_found) begin
          // Early exit on first intersect
          next_state = DONE;
        end else begin
          // Determine if all pairs have been checked
          if (rect_count < 2) begin
            next_state = DONE;
          end else begin
            // Last pair condition: i_idx == rect_count-2 and j_idx == rect_count-1
            if ((i_idx == rect_count - 2) && (j_idx == rect_count - 1)) begin
              next_state = DONE;
            end else begin
              next_state = CHECK;
            end
          end
        end
      end

      DONE: begin
        // Wait for next start to begin new computation; result is held
        if (start) begin
          if (rect_count < 2)
            next_state = DONE;
          else
            next_state = CHECK;
        end else if (load) begin
          next_state = LOAD_S;
        end else begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule