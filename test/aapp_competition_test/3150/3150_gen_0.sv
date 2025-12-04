module guard_placement_calc(
  input              clk,
  input              rst_n,
  input              start,
  input      [4:0]   num_trenches,
  input      [15:0][39:0] trenches,
  output reg [15:0]  result_count,
  output reg         done
);

  // Internal storage for trench endpoints
  // Each trench i: x1[i], y1[i], x2[i], y2[i]
  reg [9:0] x1 [0:15];
  reg [9:0] y1 [0:15];
  reg [9:0] x2 [0:15];
  reg [9:0] y2 [0:15];

  // State machine
  localparam [1:0]
    S_IDLE    = 2'b00,
    S_LOAD    = 2'b01,
    S_PROCESS = 2'b10,
    S_DONE    = 2'b11;

  reg [1:0] state, next_state;

  // Indices for combinations i < j < k
  reg [4:0] i_idx, j_idx, k_idx;

  // Internal accumulation
  reg [15:0] result_next;

  // Extract coordinates from packed input during LOAD
  integer ti;

  // Combinational signals for colinearity check
  // Use 12-bit signed intermediate for dx,dy (range within +/-1023)
  reg  signed [11:0] dx_ref;
  reg  signed [11:0] dy_ref;
  reg  signed [11:0] dx2_k, dy2_k;
  reg  signed [11:0] dx3_i, dy3_i;
  // Products: need up to 24 bits signed
  reg  signed [23:0] lhs1, rhs1;
  reg  signed [23:0] lhs2, rhs2;
  reg                colinear;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      result_count <= 16'd0;
      done         <= 1'b0;
      i_idx        <= 5'd0;
      j_idx        <= 5'd0;
      k_idx        <= 5'd0;
    end else begin
      state        <= next_state;
      result_count <= result_next;

      case (next_state)
        S_IDLE: begin
          done <= 1'b0;
        end
        S_LOAD: begin
          done <= 1'b0;
        end
        S_PROCESS: begin
          done <= 1'b0;
        end
        S_DONE: begin
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
        end
      endcase

      // Load trenches into internal arrays on transition to LOAD
      if (state == S_IDLE && next_state == S_LOAD) begin
        for (ti = 0; ti < 16; ti = ti + 1) begin
          x1[ti] <= trenches[ti][39:30];
          y1[ti] <= trenches[ti][29:20];
          x2[ti] <= trenches[ti][19:10];
          y2[ti] <= trenches[ti][9:0];
        end
      end

      // Initialize indices at start of PROCESS
      if (state == S_LOAD && next_state == S_PROCESS) begin
        i_idx <= 5'd0;
        j_idx <= 5'd1;
        k_idx <= 5'd2;
      end else if (state == S_PROCESS && next_state == S_PROCESS) begin
        // Advance combination indices: one combination per cycle
        if (num_trenches < 5'd3) begin
          // No valid combinations; indices irrelevant
          i_idx <= 5'd0;
          j_idx <= 5'd0;
          k_idx <= 5'd0;
        end else begin
          // Standard i<j<k triple iteration
          if (k_idx + 1 < num_trenches) begin
            k_idx <= k_idx + 1;
          end else if (j_idx + 2 < num_trenches) begin
            j_idx <= j_idx + 1;
            k_idx <= j_idx + 2;
          end else if (i_idx + 3 < num_trenches) begin
            i_idx <= i_idx + 1;
            j_idx <= i_idx + 2;
            k_idx <= i_idx + 3;
          end else begin
            // Completed all combinations; hold indices
            i_idx <= i_idx;
            j_idx <= j_idx;
            k_idx <= k_idx;
          end
        end
      end
    end
  end

  // Next-state and result update logic
  always @(*) begin
    next_state  = state;
    result_next = result_count;

    case (state)
      S_IDLE: begin
        // Wait for start
        if (start) begin
          result_next = 16'd0;
          next_state  = S_LOAD;
        end
      end

      S_LOAD: begin
        // One-cycle load, then move to PROCESS
        if (num_trenches < 5'd3) begin
          // No possible triplets
          next_state  = S_DONE;
          result_next = 16'd0;
        end else begin
          next_state = S_PROCESS;
        end
      end

      S_PROCESS: begin
        // Evaluate current combination (i_idx,j_idx,k_idx)
        // Only if within valid range and ordering
        if (num_trenches >= 5'd3 &&
            i_idx < num_trenches &&
            j_idx < num_trenches &&
            k_idx < num_trenches &&
            (i_idx < j_idx) && (j_idx < k_idx)) begin
          // Colinearity check
          // Reference line: trench i
          dx_ref = $signed({1'b0, x2[i_idx]}) - $signed({1'b0, x1[i_idx]});
          dy_ref = $signed({1'b0, y2[i_idx]}) - $signed({1'b0, y1[i_idx]});

          // Trench j endpoints relative to trench i start
          dx2_k = $signed({1'b0, x1[j_idx]}) - $signed({1'b0, x1[i_idx]});
          dy2_k = $signed({1'b0, y1[j_idx]}) - $signed({1'b0, y1[i_idx]});

          // Trench k endpoints relative to trench i start
          dx3_i = $signed({1'b0, x1[k_idx]}) - $signed({1'b0, x1[i_idx]});
          dy3_i = $signed({1'b0, y1[k_idx]}) - $signed({1'b0, y1[i_idx]});

          // Cross products
          lhs1 = dx_ref * dy2_k;
          rhs1 = dy_ref * dx2_k;
          lhs2 = dx_ref * dy3_i;
          rhs2 = dy_ref * dx3_i;

          colinear = (lhs1 == rhs1) && (lhs2 == rhs2);

          if (colinear) begin
            result_next = result_count + 16'd1;
          end
        end

        // Determine if this was the last valid combination
        if (num_trenches < 5'd3) begin
          next_state = S_DONE;
        end else begin
          // Compute what the next indices would be to know if we are done
          if ( (i_idx + 3 >= num_trenches) &&
               ( (j_idx + 2 >= num_trenches) || (i_idx + 3 >= num_trenches) ) &&
               (k_idx + 1 >= num_trenches) ) begin
            // However, above is approximate; use explicit end condition:
            // Done when i == N-3, j == N-2, k == N-1 and we've just processed it.
            if ((i_idx == (num_trenches - 3)) &&
                (j_idx == (num_trenches - 2)) &&
                (k_idx == (num_trenches - 1))) begin
              next_state = S_DONE;
            end else begin
              next_state = S_PROCESS;
            end
          end else begin
            next_state = S_PROCESS;
          end
        end
      end

      S_DONE: begin
        // Hold result until a new start
        if (start) begin
          result_next = 16'd0;
          next_state  = S_LOAD;
        end
      end

      default: begin
        next_state  = S_IDLE;
        result_next = 16'd0;
      end
    endcase
  end

endmodule