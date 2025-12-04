module robotic_arm_controller(
  input clk,
  input rst_n,
  input start,
  input [2:0] N, // 1-8 segments
  input [15:0] L_0,
  input [15:0] L_1,
  input [15:0] L_2,
  input [15:0] L_3,
  input [15:0] L_4,
  input [15:0] L_5,
  input [15:0] L_6,
  input [15:0] L_7,
  input [31:0] target_x, // Q16.16
  input [31:0] target_y, // Q16.16
  output reg [31:0] x_0, y_0, // segment 1 tip (index 0)
  output reg [31:0] x_1, y_1,
  output reg [31:0] x_2, y_2,
  output reg [31:0] x_3, y_3,
  output reg [31:0] x_4, y_4,
  output reg [31:0] x_5, y_5,
  output reg [31:0] x_6, y_6,
  output reg [31:0] x_7, y_7, // last segment tip (index 7)
  output reg done
);

  // Q16.16 distance threshold: 0.01 -> 0.01 * 2^16 = 655 (decimal)
  localparam signed [31:0] THRESHOLD = 32'h0000028F; // 655
  localparam integer W = 32;

  // State
  reg [2:0] count_r;
  reg [31:0] pos_x, pos_y;  // current base position for the next segment (Q16.16)
  reg running;

  // Helper: choose segment length by index
  function [15:0] pick_len(input [2:0] idx);
    case (idx)
      3'd0: pick_len = L_0;
      3'd1: pick_len = L_1;
      3'd2: pick_len = L_2;
      3'd3: pick_len = L_3;
      3'd4: pick_len = L_4;
      3'd5: pick_len = L_5;
      3'd6: pick_len = L_6;
      default: pick_len = L_7; // 3'd7
    endcase
  endfunction

  // Helper: 1/sqrt(x) for positive x using iterative refinement (fixed-point)
  function [31:0] invsqrt_q16_16(input [31:0] x);
    reg [31:0] y;
    reg [63:0] t;
    integer i;
    begin
      // Initial guess: 0.5 * 2^(16 - log2(x)/2)  -> approximate in [1,2) range
      if (x[31:16] == 16'd0) begin
        // avoid /0; use safe initial value
        y = 32'h00010000; // 1.0 in Q16.16
      end else begin
        // y0 approx = 0.5/sqrt(x) scaled to Q16.16
        y = (32'h8000) >> ((x[30:16] == 15'd0) ? 1 : ((x[30:16] >> 1) + 1));
        if (y == 0) y = 32'h00010000;
      end
      // 3 iterations of Newton-Raphson: y_{n+1} = 0.5*y*(3 - x*y^2)
      for (i = 0; i < 3; i = i + 1) begin
        t = $unsigned(y) * $unsigned(y);             // y^2
        t = $unsigned(x) * t;                         // x*y^2
        t = 64'h000300000000 - t;                     // 3 - x*y^2
        t = t * $unsigned(y);                         // y*(3 - x*y^2)
        y = t[47:16];                                 // 0.5*y*(3 - x*y^2)
      end
      invsqrt_q16_16 = y;
    end
  endfunction

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running <= 1'b0;
      done <= 1'b0;
      count_r <= 3'd0;
      pos_x <= 32'd0;
      pos_y <= 32'd0;
      x_0 <= 32'd0; y_0 <= 32'd0;
      x_1 <= 32'd0; y_1 <= 32'd0;
      x_2 <= 32'd0; y_2 <= 32'd0;
      x_3 <= 32'd0; y_3 <= 32'd0;
      x_4 <= 32'd0; y_4 <= 32'd0;
      x_5 <= 32'd0; y_5 <= 32'd0;
      x_6 <= 32'd0; y_6 <= 32'd0;
      x_7 <= 32'd0; y_7 <= 32'd0;
    end else begin
      if (!start) begin
        // Clear all outputs when start=0
        running <= 1'b0;
        done <= 1'b0;
        count_r <= 3'd0;
        pos_x <= 32'd0;
        pos_y <= 32'd0;
        x_0 <= 32'd0; y_0 <= 32'd0;
        x_1 <= 32'd0; y_1 <= 32'd0;
        x_2 <= 32'd0; y_2 <= 32'd0;
        x_3 <= 32'd0; y_3 <= 32'd0;
        x_4 <= 32'd0; y_4 <= 32'd0;
        x_5 <= 32'd0; y_5 <= 32'd0;
        x_6 <= 32'd0; y_6 <= 32'd0;
        x_7 <= 32'd0; y_7 <= 32'd0;
      end else begin
        if (!running) begin
          // Start cycle 0: base at origin, output segment 1 tip at index 0
          running <= 1'b1;
          done <= 1'b0;
          count_r <= 3'd0;
          pos_x <= 32'd0;
          pos_y <= 32'd0;
        end

        if (running) begin
          if (count_r < N) begin
            // Compute direction to target
            {1'b0, pos_x}; // ensure unsigned view
            {1'b0, pos_y};
            // Use signed arithmetic for dx, dy
            wire signed [31:0] dx = $signed(target_x) - $signed(pos_x);
            wire signed [31:0] dy = $signed(target_y) - $signed(pos_y);

            // Distance squared (unsigned, saturate to max if negative due to overflow)
            wire [63:0] dx2 = $unsigned($signed(dx) * $signed(dx));
            wire [63:0] dy2 = $unsigned($signed(dy) * $signed(dy));
            wire [63:0] dist2 = dx2 + dy2;
            // Distance
            wire [31:0] dist_q16_16 = dist2[63:32] ? 32'hFFFFFFFF : $sqrt(dist2);

            // Normalization (unit vector) or direct pointing if close
            wire [31:0] inv_norm;
            wire [31:0] ux, uy; // unit vector in Q16.16
            wire is_close = (dist_q16_16 < THRESHOLD) ? 1'b1 : 1'b0;

            if (is_close) begin
              // Directly towards target
              ux <= dx;
              uy <= dy;
            end else begin
              inv_norm = invsqrt_q16_16(dist_q16_16);
              ux <= $signed(dx) * $signed(inv_norm);
              uy <= $signed(dy) * $signed(inv_norm);
            end

            // Step by segment length (L_i is Q16.0)
            wire signed [31:0] step_x = $signed(ux) * $signed({1'b0, pick_len(count_r)});
            wire signed [31:0] step_y = $signed(uy) * $signed({1'b0, pick_len(count_r)});
            wire signed [31:0] next_x = $signed(pos_x) + step_x;
            wire signed [31:0] next_y = $signed(pos_y) + step_y;

            // Write current tip to output port with the same index as the segment number
            case (count_r)
              3'd0: begin x_0 <= next_x; y_0 <= next_y; end
              3'd1: begin x_1 <= next_x; y_1 <= next_y; end
              3'd2: begin x_2 <= next_x; y_2 <= next_y; end
              3'd3: begin x_3 <= next_x; y_3 <= next_y; end
              3'd4: begin x_4 <= next_x; y_4 <= next_y; end
              3'd5: begin x_5 <= next_x; y_5 <= next_y; end
              3'd6: begin x_6 <= next_x; y_6 <= next_y; end
              default: begin x_7 <= next_x; y_7 <= next_y; end // 3'd7
            endcase

            pos_x <= next_x;
            pos_y <= next_y;
            count_r <= count_r + 1;
            done <= (count_r + 1 == N);
          end else begin
            // Completed
            done <= 1'b1;
          end
        end
      end
    end
  end

endmodule
