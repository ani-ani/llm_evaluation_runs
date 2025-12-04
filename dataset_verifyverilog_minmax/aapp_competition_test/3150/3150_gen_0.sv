module guard_placement_calc (
  input clk, rst_n,
  input start,
  input [4:0] num_trenches,
  input [15:0][39:0] trenches,
  output reg [15:0] result_count,
  output reg done
);

  // Packed trench format: [39:36] x1[9:0], [35:32] y1[9:0], [31:28] x2[9:0], [27:24] y2[9:0]
  typedef struct packed {
    logic [9:0] x1;
    logic [9:0] y1;
    logic [9:0] x2;
    logic [9:0] y2;
  } trench_t;

  typedef enum logic [1:0] { IDLE = 2'b00, LOAD = 2'b01, PROCESS = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  trench_t mem [0:15];  // store up to 16 trenches
  logic [3:0] n_tr;     // local copy of num_trenches (0..16)

  // Combination counters (C(16,3) = 560)
  logic [9:0] comb_id;      // 0..559
  logic [9:0] comb_limit;   // C(n,3)
  logic [7:0] comb_i;       // 0..13
  logic [7:0] comb_j;       // 1..14
  logic [7:0] comb_k;       // 2..15
  logic is_done;            // comb_id == comb_limit

  // Collinearity temp results
  logic col_ij_k; // points i and j define the line, point k on it?
  logic col_ik_j; // points i and k define the line, point j on it?
  logic col_jk_i; // points j and k define the line, point i on it?

  // Precompute comb_limit from n_tr
  function [9:0] comb3(input [7:0] n);
    if (n < 3) comb3 = 0;
    else       comb3 = (n * (n - 1) * (n - 2)) / 6;
  endfunction

  // Collinearity check using cross product (exact for integer coords):
  // (x2-x1)*(y3-y1) == (y2-y1)*(x3-x1)
  function colinear(input [9:0] x1, y1, x2, y2, x3, y3);
    logic signed [20:0] dx21, dy21, dx31, dy31;
    logic signed [41:0] left, right;
    dx21 = $signed({1'b0, x2}) - $signed({1'b0, x1});
    dy21 = $signed({1'b0, y2}) - $signed({1'b0, y1});
    dx31 = $signed({1'b0, x3}) - $signed({1'b0, x1});
    dy31 = $signed({1'b0, y3}) - $signed({1'b0, y1});
    left  = dx21 * dy31;
    right = dy21 * dx31;
    colinear = (left == right);
  endfunction

  // Sequential logic: reset, state, counters, result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result_count <= 16'h0;
      comb_id <= 10'h0;
      comb_limit <= 10'h0;
      n_tr <= 4'h0;
    end else begin
      // Default: hold
      done <= 1'b0;

      // State machine
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
          end
        end

        LOAD: begin
          // Capture inputs
          n_tr <= num_trenches[3:0];
          for (int t = 0; t < 16; t++) begin
            if (t < num_trenches) begin
              mem[t].x1 = trenches[t][39:30];
              mem[t].y1 = trenches[t][29:20];
              mem[t].x2 = trenches[t][19:10];
              mem[t].y2 = trenches[t][9:0];
            end else begin
              mem[t].x1 = 10'h0;
              mem[t].y1 = 10'h0;
              mem[t].x2 = 10'h0;
              mem[t].y2 = 10'h0;
            end
          end
          // Initialize counters and outputs for processing
          comb_id <= 10'h0;
          comb_limit <= comb3(num_trenches);
          result_count <= 16'h0;
          state <= PROCESS;
        end

        PROCESS: begin
          if (!is_done) begin
            // Evaluate current combination (comb_id) for collinearity
            if (col_ij_k || col_ik_j || col_jk_i) begin
              result_count <= result_count + 1;
            end
            // Advance to next combination
            comb_id <= comb_id + 1;
            if (comb_id + 1 == comb_limit) begin
              // Next cycle will be done
            end
          end
          if (is_done) begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Wait for start deassertion to return to IDLE
          if (!start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Compute comb_limit from n_tr (updated in LOAD)
  always_comb begin
    comb_limit = comb3(n_tr);
  end

  // Determine if all combinations processed
  assign is_done = (comb_id >= comb_limit);

  // Map comb_id to (i, j, k) with i < j < k and i,j,k in [0, n_tr-1]
  // Computation uses integer arithmetic (60 ops per combination, acceptable at 1 comb/cycle)
  always_comb begin
    logic [9:0] s1, s2, s3;
    logic [7:0] n;
    n = n_tr;

    // Default to safe values (won't be used when n<3)
    comb_i = 8'h0;
    comb_j = 8'h1;
    comb_k = 8'h2;

    if (n >= 3 && comb_id < comb_limit) begin
      // Find i such that C(i,3) <= id < C(i+1,3)
      // C(i,3) = i*(i-1)*(i-2)/6 for i>=3; define C(0,3)=C(1,3)=C(2,3)=0
      for (int ii = 3; ii <= 16; ii++) begin
        if (ii > n) break;
        s1 = comb3(ii);
        if (comb_id < s1) begin
          comb_i = ii - 1; // i is the last value where C(i,3) <= id
          break;
        end
      end

      // s2 = C(i+1,3) = C(i,3) + C(i,2)
      s2 = comb3(comb_i + 1);
      s1 = comb3(comb_i);
      // Find j such that s1 + C(j-i-1,2) <= id < s1 + C(j-i,2)
      for (int jj = comb_i + 2; jj <= 16; jj++) begin
        if (jj > n) break;
        s3 = s1 + comb3(jj - comb_i);
        if (comb_id < s3) begin
          comb_j = jj - 1; // j is the last value satisfying the range
          break;
        end
      end

      // k is what's left to reach comb_id within the (i,j) block
      // k_offset satisfies: id = s1 + C(j-i,2) + k_offset, 0 <= k_offset < (n - j)
      s3 = s1 + comb3(comb_j - comb_i);
      s2 = comb3(comb_j + 1 - comb_i); // = C(j-i,2) + (j-i)
      s1 = s1 + comb3(comb_j - comb_i);
      s2 = s1 + (comb_j + 1 - comb_i);

      // More directly:
      // k_offset = id - [C(i,3) + C(j-i,2)]
      // k = j + 1 + k_offset
      s1 = comb3(comb_i);                          // C(i,3)
      s2 = comb3(comb_j - comb_i);                 // C(j-i,2)
      s3 = s1 + s2;                                // offset base for k
      comb_k = comb_j + 1 + (comb_id - s3);
    end
  end

  // Evaluate collinearity for the current (i, j, k)
  // Three possibilities: line from (i), from (j), or from (k)
  always_comb begin
    // Default to fail
    col_ij_k = 1'b0;
    col_ik_j = 1'b0;
    col_jk_i = 1'b0;

    if (n_tr >= 3) begin
      // Points from trenches
      logic [9:0] xi, yi, xj, yj, xk, yk;
      xi = mem[comb_i].x1; yi = mem[comb_i].y1;
      xj = mem[comb_j].x1; yj = mem[comb_j].y1;
      xk = mem[comb_k].x1; yk = mem[comb_k].y1;

      // Guard 1 and 2 define the line, check guard 3
      col_ij_k = colinear(xi, yi, xj, yj, xk, yk);
      // Guard 1 and 3 define the line, check guard 2
      col_ik_j = colinear(xi, yi, xk, yk, xj, yj);
      // Guard 2 and 3 define the line, check guard 1
      col_jk_i = colinear(xj, yj, xk, yk, xi, yi);
    end
  end

endmodule
