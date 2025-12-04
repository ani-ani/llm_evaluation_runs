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
  // FSM states
  typedef enum logic [1:0] {IDLE=2'b00, COMPARE=2'b01, DONE=2'b10} state_t;
  state_t state, next_state;

  // Storage for up to 8 rectangles (signed 16-bit)
  logic [15:0] rect_x1 [0:7];
  logic [15:0] rect_y1 [0:7];
  logic [15:0] rect_x2 [0:7];
  logic [15:0] rect_y2 [0:7];

  // Count of stored rectangles (0..8)
  logic [3:0] rect_count, next_rect_count;
  // Write pointer for loading
  logic [2:0] wr_ptr, next_wr_ptr;

  // Pairwise comparison indices
  logic [2:0] i_cur, j_cur;
  logic [2:0] i_next, j_next;

  // Pair count for current set
  logic [4:0] pair_count, next_pair_count;
  // Remaining pairs to check (not needed for control but kept for clarity)
  logic [4:0] pairs_left, next_pairs_left;

  // Registered outputs
  logic result_next;
  logic done_next;

  // State and control registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      rect_count <= 4'd0;
      wr_ptr <= 3'd0;
      i_cur <= 3'd0;
      j_cur <= 3'd1;
      pair_count <= 5'd0;
      pairs_left <= 5'd0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      rect_count <= next_rect_count;
      wr_ptr <= next_wr_ptr;
      i_cur <= i_next;
      j_cur <= j_next;
      pair_count <= next_pair_count;
      pairs_left <= next_pairs_left;
      result <= result_next;
      done <= done_next;
    end
  end

  // Storage write (synchronously on load)
  always_ff @(posedge clk) begin
    if (load && wr_ptr < 4'd8) begin
      rect_x1[wr_ptr] <= x1;
      rect_y1[wr_ptr] <= y1;
      rect_x2[wr_ptr] <= x2;
      rect_y2[wr_ptr] <= y2;
    end
  end

  // Helper to compute the number of pairs: C(n,2) = n*(n-1)/2
  function [4:0] comb2 (input [3:0] n);
    comb2 = (n >= 2) ? ({1'b0, n} * {1'b0, n - 4'd1}) >> 1 : 5'd0;
  endfunction

  always_comb begin
    // Defaults
    next_state = state;
    next_rect_count = rect_count;
    next_wr_ptr = wr_ptr;
    i_next = i_cur;
    j_next = j_cur;
    next_pair_count = pair_count;
    next_pairs_left = pairs_left;
    result_next = result;
    done_next = done;

    case (state)
      IDLE: begin
        // Load rectangles
        if (load && rect_count < 4'd8) begin
          next_rect_count = rect_count + 4'd1;
          next_wr_ptr = wr_ptr + 3'd1;
        end
        done_next = 1'b0; // Not busy while loading

        // Start checking when requested
        if (start && rect_count >= 4'd2) begin
          next_state = COMPARE;
          next_pair_count = comb2(rect_count);
          next_pairs_left = comb2(rect_count);
          i_next = 3'd0;
          j_next = 3'd1;
          result_next = 1'b0;
          done_next = 1'b0;
        end
      end

      COMPARE: begin
        // One pair per cycle
        if (next_pair_count > 5'd0) begin
          // Increment j first to keep lexicographic order (0,1),(0,2),...,(0,7),(1,2),...)
          if (j_cur < 3'd7) begin
            i_next = i_cur;
            j_next = j_cur + 3'd1;
            next_pairs_left = next_pairs_left - 5'd1;
          end else begin
            i_next = i_cur + 3'd1;
            j_next = i_cur + 3'd2;
            next_pairs_left = next_pairs_left - 5'd1;
          end
          next_pair_count = next_pair_count - 5'd1;

          // Intersection test (boundary-touching does NOT count)
          if (
            !(rect_x2[i_next] <= rect_x1[j_next] ||
              rect_x2[j_next] <= rect_x1[i_next] ||
              rect_y2[i_next] <= rect_y1[j_next] ||
              rect_y2[j_next] <= rect_y1[i_next])
          ) begin
            result_next = 1'b1;
            next_state = DONE;
            done_next = 1'b1;
          end else if (next_pair_count == 5'd1) begin
            // Last pair processed without finding any intersection
            result_next = 1'b0;
            next_state = DONE;
            done_next = 1'b1;
          end
        end
      end

      DONE: begin
        // Remain in DONE until a new start pulse, keeping result stable
        if (start && rect_count >= 4'd2) begin
          next_state = COMPARE;
          next_pair_count = comb2(rect_count);
          next_pairs_left = comb2(rect_count);
          i_next = 3'd0;
          j_next = 3'd1;
          result_next = 1'b0;
          done_next = 1'b0;
        end
      end

      default: next_state = IDLE;
    endcase
  end
endmodule