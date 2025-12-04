module galactic_path_optimizer (
  input clk,
  input rst_n,
  input start,
  input [8:0] x1, y1, z1,
  input [8:0] x2, y2, z2,
  input [8:0] x3, y3, z3,
  input [8:0] x4, y4, z4,
  output reg [31:0] min_distance,
  output reg done
);

  // State definitions
  typedef enum {
    IDLE,
    CALC_DIST,
    SQRT_WAIT,
    EVAL_PATTERNS,
    COMPARE,
    FINISH
  } state_t;
  state_t current_state, next_state;

  // Pairwise squared distances
  reg [31:0] d12_sq, d13_sq, d14_sq, d23_sq, d24_sq, d34_sq;
  reg [31:0] d12, d13, d14, d23, d24, d34;

  // Evaluation registers
  reg [31:0] pattern_distances [0:5];
  reg [31:0] current_min;
  reg [2:0] pattern_counter;
  reg [5:0] cycle_counter;

  // Combinational square root approximation
  function automatic [31:0] approx_sqrt;
    input [31:0] val;
    reg [31:0] res;
    reg [31:0] bit;
    reg [31:0] num;
    begin
      if (val == 0) approx_sqrt = 0;
      else begin
        res = 0;
        num = val;
        bit = 1 << 30; // Using 16 fractional bits (Q16.16)
        while (bit > num) bit = bit >> 2;
        while (bit != 0) begin
          if (num >= res + bit) begin
            num = num - (res + bit);
            res = (res >> 1) + bit;
          end
          else res = res >> 1;
          bit = bit >> 2;
        }
        approx_sqrt = res << 8; // Scale integer to Q16.16
      end
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      current_state <= IDLE;
      done <= 0;
      min_distance <= 0;
      cycle_counter <= 0;
      pattern_counter <= 0;
    end
    else begin
      current_state <= next_state;
      cycle_counter <= cycle_counter + 1;

      case(current_state)
        IDLE: begin
          done <= 0;
          cycle_counter <= 0;
          if (start) begin
            // Calculate squared differences
            d12_sq <= (x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2);
            d13_sq <= (x1-x3)*(x1-x3) + (y1-y3)*(y1-y3) + (z1-z3)*(z1-z3);
            d14_sq <= (x1-x4)*(x1-x4) + (y1-y4)*(y1-y4) + (z1-z4)*(z1-z4);
            d23_sq <= (x2-x3)*(x2-x3) + (y2-y3)*(y2-y3) + (z2-z3)*(z2-z3);
            d24_sq <= (x2-x4)*(x2-x4) + (y2-y4)*(y2-y4) + (z2-z4)*(z2-z4);
            d34_sq <= (x3-x4)*(x3-x4) + (y3-y4)*(y3-y4) + (z3-z4)*(z3-z4);
            next_state <= CALC_DIST;
          end
        end

        CALC_DIST: begin
          // Approximate sqrt in Q16.16 format
          d12 <= approx_sqrt(d12_sq);
          d13 <= approx_sqrt(d13_sq);
          d14 <= approx_sqrt(d14_sq);
          d23 <= approx_sqrt(d23_sq);
          d24 <= approx_sqrt(d24_sq);
          d34 <= approx_sqrt(d34_sq);
          next_state <= SQRT_WAIT;
        end

        SQRT_WAIT: begin
          // Allow 2 cycles for approximation
          if (cycle_counter >= 3) next_state <= EVAL_PATTERNS;
        end

        EVAL_PATTERNS: begin
          if (pattern_counter < 6) begin
            case(pattern_counter)
              0: pattern_distances[0] <= d23 + d34 + d41;  // Path: 1-(2 free)-3-4-1
              1: pattern_distances[1] <= d13 + d34 + d42;  // Path: 1-3-4-2-(1 free)
              2: pattern_distances[2] <= d12 + d24 + d43;  // Path: 1-2-4-3-(1 free)
              3: pattern_distances[3] <= d13 + d32 + d24;  // Path: 1-3-2-4-(1 free)
              4: pattern_distances[4] <= d14 + d42 + d23;  // Path: 1-4-2-3-(1 free)
              5: pattern_distances[5] <= d14 + d43 + d32;  // Path: 1-4-3-2-(1 free)
            endcase
            pattern_counter <= pattern_counter + 1;
          end
          else next_state <= COMPARE;
        end

        COMPARE: begin
          current_min <= pattern_distances[0];
          for (int i = 1; i < 6; i++) begin
            if (pattern_distances[i] < current_min)
              current_min <= pattern_distances[i];
          end
          next_state <= FINISH;
        end

        FINISH: begin
          min_distance <= current_min;
          done <= 1;
          if (cycle_counter >= 50) next_state <= IDLE;
        end
      endcase
    end
  end

  // Constant d41 alias (same as d14 due to symmetry)
  wire [31:0] d41 = d14;
  wire [31:0] d42 = d24;
  wire [31:0] d43 = d34;
  wire [31:0] d32 = d23;

  always_comb begin
    next_state = current_state;
    if (~rst_n) next_state = IDLE;
  end

endmodule
