module max_fruits_sliced(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Number of fruits (1-8)
  input [31:0] x [0:7], // Q16.16 fixed-point x coordinates (8 fruits)
  input [31:0] y [0:7], // Q16.16 fixed-point y coordinates (8 fruits)
  output reg [3:0] max_count, // Maximum fruits sliced (0-8)
  output reg done // High when computation complete
);

  // Constants for Q16.16 fixed-point
  localparam Q16 = 16;
  localparam ONE = 32'h0001_0000; // 1.0 in Q16.16
  localparam TWO = 32'h0002_0000; // 2.0 in Q16.16
  localparam FOUR = 32'h0004_0000; // 4.0 in Q16.16

  // State machine
  typedef enum logic [1:0] {
    S_IDLE        = 2'b00,
    S_PAIR        = 2'b01,
    S_CHECK_LINE  = 2'b10,
    S_FINISH      = 2'b11
  } state_t;
  state_t state, next_state;

  // Pair iteration
  logic [7:0] pair_i_idx;   // i in [0..7]
  logic [7:0] pair_j_idx;   // j in [i+1..7]
  logic [7:0] next_i, next_j;
  logic last_pair;

  // Per-line parameters (Q16.16)
  logic signed [31:0] line_c0, line_c1; // c in ax + by + c = 0
  logic signed [31:0] line_a, line_b;   // line direction vector components
  logic line_valid0, line_valid1;       // Lines exist if centers >= 2 apart

  // Active line selection
  logic active_line;        // 0 -> use line0, 1 -> use line1
  logic [2:0] count;        // Sliced fruits for current line (0..8)

  // Helpers
  function signed [31:0] mul_q16(input signed [31:0] a, input signed [31:0] b);
    // Q16.16 * Q16.16 -> Q16.16, proper rounding
    automatic logic signed [63:0] tmp;
    tmp = $signed({a, 16'b0}) * $signed({b, 16'b0});
    // Keep high 32 bits after shifting 16 fractional bits, add MSB for rounding
    mul_q16 = tmp[63:16] + tmp[15];
  endfunction

  function signed [31:0] sub_q16(input signed [31:0] a, input signed [31:0] b);
    sub_q16 = a - b;
  endfunction

  function signed [31:0] add_q16(input signed [31:0] a, input signed [31:0] b);
    add_q16 = a + b;
  endfunction

  function logic intersects_circle(
    input signed [31:0] a, // line: a*x + b*y + c = 0
    input signed [31:0] b,
    input signed [31:0] c,
    input signed [31:0] px,
    input signed [31:0] py
  );
    // Return 1 if circle centered at (px,py) with radius 1 is intersected by the line
    // Using squared comparison: (|a*x+b*y+c| <= r^2 * (a^2+b^2))
    // Here r^2 = 1.0 => 0x00010000 in Q16.16
    automatic signed [31:0] num = a * px + b * py + c;
    // num^2
    automatic logic signed [63:0] num2_full = $signed({num, 16'b0}) * $signed({num, 16'b0});
    automatic signed [31:0] num2 = num2_full[63:16] + num2_full[15];
    // a^2 + b^2
    automatic signed [31:0] a2b2 = (a * a) + (b * b);
    // 1.0 * (a^2 + b^2)
    automatic signed [31:0] rhs = ONE * a2b2;
    intersects_circle = (num2 <= rhs);
  endfunction

  // Compute per-pair lines
  always @(*) begin
    // Default to zero/valid=0
    line_a = 0;
    line_b = 0;
    line_c0 = 0;
    line_c1 = 0;
    line_valid0 = 1'b0;
    line_valid1 = 1'b0;
    if (n >= 3 && pair_i_idx < n && pair_j_idx < n && pair_i_idx != pair_j_idx) begin
      automatic signed [31:0] xi = $signed(x[pair_i_idx]);
      automatic signed [31:0] yi = $signed(y[pair_i_idx]);
      automatic signed [31:0] xj = $signed(x[pair_j_idx]);
      automatic signed [31:0] yj = $signed(y[pair_j_idx]);
      automatic signed [31:0] dx = sub_q16(xj, xi);
      automatic signed [31:0] dy = sub_q16(yj, yi);
      // Vector magnitude squared (d^2)
      automatic signed [31:0] d2 = mul_q16(dx, dx) + mul_q16(dy, dy);
      // Compare d2 with (2.0)^2 = 4.0
      if (d2 > FOUR) begin
        // Lines exist: a = dy, b = -dx (perpendicular to vector i->j)
        line_a = dy;
        line_b = -dx;
        // c values for both supporting lines through centers
        line_c0 = -(line_a * xi + line_b * yi); // line through i
        line_c1 = -(line_a * xj + line_b * yj); // line through j
        line_valid0 = 1'b1;
        line_valid1 = 1'b1;
      end else begin
        // Centers closer than 2 units: tangential lines degenerate; do not consider
        line_valid0 = 1'b0;
        line_valid1 = 1'b0;
      end
    end
  end

  // Pair index management (i<j)
  always @(*) begin
    if (pair_i_idx < n - 1) begin
      next_i = pair_i_idx;
      next_j = pair_j_idx + 1;
    end else begin
      next_i = 8'h00;
      next_j = 8'h01;
    end
    last_pair = (pair_i_idx == n - 2) && (pair_j_idx == n - 1);
  end

  // Sequential logic with registered outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      max_count <= 4'b0;
      done <= 1'b0;
      pair_i_idx <= 8'h00;
      pair_j_idx <= 8'h01;
      active_line <= 1'b0;
      count <= 3'b0;
    end else begin
      // State transitions and datapath
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= S_PAIR;
            pair_i_idx <= 8'h00;
            pair_j_idx <= 8'h01;
            // Initialize for first pair (next cycle will evaluate)
            active_line <= 1'b0;
            count <= 3'b0;
          end else begin
            state <= S_IDLE;
            max_count <= 4'b0;
          end
        end

        S_PAIR: begin
          // Initialize for the current pair
          count <= 3'b0;
          active_line <= 1'b0; // start with line0
          state <= S_CHECK_LINE;
        end

        S_CHECK_LINE: begin
          // Evaluate current line for fruit at index 'count'
          if (count < n) begin
            if (active_line == 1'b0) begin
              // Evaluating line0 through fruit i
              if (line_valid0) begin
                if (intersects_circle(line_a, line_b, line_c0, $signed(x[count]), $signed(y[count]))) begin
                  max_count <= max_count + 1; // increment max_count if sliced
                end
              end
            end else begin
              // Evaluating line1 through fruit j
              if (line_valid1) begin
                if (intersects_circle(line_a, line_b, line_c1, $signed(x[count]), $signed(y[count]))) begin
                  max_count <= max_count + 1; // increment max_count if sliced
                end
              end
            end
            // Advance to next fruit on this line
            count <= count + 1;
          end else begin
            // Finished checking all fruits for current line
            if (active_line == 1'b0) begin
              // Switch to line1 (through fruit j) if it exists
              if (line_valid1) begin
                active_line <= 1'b1;
                count <= 3'b0;
              end else begin
                // No second line; move to next pair or finish
                if (last_pair) begin
                  state <= S_FINISH;
                  done <= 1'b1;
                end else begin
                  state <= S_PAIR;
                  pair_i_idx <= next_i;
                  pair_j_idx <= next_j;
                end
              end
            end else begin
              // Second line done; move to next pair or finish
              if (last_pair) begin
                state <= S_FINISH;
                done <= 1'b1;
              end else begin
                state <= S_PAIR;
                pair_i_idx <= next_i;
                pair_j_idx <= next_j;
              end
            end
          end
        end

        S_FINISH: begin
          done <= 1'b1;
          if (!start) begin
            state <= S_IDLE;
            max_count <= 4'b0;
          end else begin
            state <= S_FINISH;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule