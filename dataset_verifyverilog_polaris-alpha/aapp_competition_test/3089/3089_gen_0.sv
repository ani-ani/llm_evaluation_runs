module taxi_distance_calculator(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_vertices,
  input [31:0] vertices_x [0:7],
  input [31:0] vertices_y [0:7],
  output reg [31:0] expected,
  output reg done
);

  // Parameters
  localparam S_IDLE       = 3'd0;
  localparam S_INIT       = 3'd1;
  localparam S_GEN_P1     = 3'd2;
  localparam S_GEN_P2     = 3'd3;
  localparam S_CHECK_P1   = 3'd4;
  localparam S_CHECK_P2   = 3'd5;
  localparam S_ACCUM      = 3'd6;
  localparam S_DONE       = 3'd7;

  localparam NUM_SAMPLES  = 10'd1024; // 1024 samples

  // Internal registers
  reg [2:0] state, next_state;

  // Polygon vertices storage
  reg [31:0] vx [0:7];
  reg [31:0] vy [0:7];
  reg [2:0]  n_verts;

  // Bounding box in Q16.16
  reg [31:0] min_x, max_x, min_y, max_y;

  // LFSR for random number generation (8-bit)
  reg [7:0] lfsr;
  wire lfsr_feedback;
  assign lfsr_feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

  // Sample counters and accumulation
  reg [9:0] valid_sample_cnt; // up to 1024
  reg [47:0] sum_accum;       // holds sum of distances (Q16.16) with headroom

  // Random points Q16.16
  reg [31:0] p1_x, p1_y;
  reg [31:0] p2_x, p2_y;

  // Inside-polygon flags
  reg p1_inside;
  reg p2_inside;

  // Distances
  reg [31:0] manhattan_dist;

  // Temporary for min/max calculations
  integer i;

  // Absolute difference function (Q16.16, 32-bit)
  function [31:0] abs_diff32;
    input [31:0] a;
    input [31:0] b;
    begin
      if (a >= b)
        abs_diff32 = a - b;
      else
        abs_diff32 = b - a;
    end
  endfunction

  // Sign function for 32-bit signed
  function integer sign32;
    input signed [31:0] v;
    begin
      if (v > 0)
        sign32 = 1;
      else if (v < 0)
        sign32 = -1;
      else
        sign32 = 0;
    end
  endfunction

  // Forward cross product sign for convex polygon inside test
  // Checks if point P is consistently on the same side of all edges.
  function is_inside_convex;
    input [31:0] px;
    input [31:0] py;
    input [2:0]  n;
    input [31:0] vx_local [0:7];
    input [31:0] vy_local [0:7];
    integer j, k;
    reg signed [31:0] x1, y1, x2, y2;
    reg signed [31:0] v1x, v1y, v2x, v2y;
    reg signed [63:0] cross;
    integer s, curr_s;
    begin
      s = 0;
      for (j = 0; j < 8; j = j + 1) begin
        if (j < n) begin
          k = (j + 1 < n) ? (j + 1) : 0;
          x1 = vx_local[j];
          y1 = vy_local[j];
          x2 = vx_local[k];
          y2 = vy_local[k];
          v1x = x2 - x1;
          v1y = y2 - y1;
          v2x = px - x1;
          v2y = py - y1;
          cross = v1x * v2y - v1y * v2x;
          curr_s = sign32(cross[63:32] != 0 ? cross[63:32] : cross[31:0]);
          if (curr_s != 0) begin
            if (s == 0)
              s = curr_s;
            else if (curr_s != s) begin
              is_inside_convex = 1'b0;
              disable is_inside_convex;
            end
          end
        end
      end
      is_inside_convex = 1'b1;
    end
  endfunction

  // Generate random Q16.16 within [min,max] using LFSR (8-bit fraction scaling)
  function [31:0] rand_in_range_q16_16;
    input [31:0] min_v;
    input [31:0] max_v;
    input [7:0]  rnd;
    reg [31:0] span;
    reg [31:0] scaled;
    begin
      if (max_v <= min_v) begin
        rand_in_range_q16_16 = min_v;
      end else begin
        span = max_v - min_v; // Q16.16
        // Scale 8-bit random to Q0.8, then multiply span and keep high bits.
        // (span * rnd) >> 8
        scaled = (span * rnd) >> 8;
        rand_in_range_q16_16 = min_v + scaled;
      end
    end
  endfunction

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // LFSR update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lfsr <= 8'hA5; // non-zero seed
    end else begin
      // advance every cycle for simplicity
      lfsr <= {lfsr[6:0], lfsr_feedback};
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done              <= 1'b0;
      expected          <= 32'd0;
      valid_sample_cnt  <= 10'd0;
      sum_accum         <= 48'd0;
      p1_x              <= 32'd0;
      p1_y              <= 32'd0;
      p2_x              <= 32'd0;
      p2_y              <= 32'd0;
      p1_inside         <= 1'b0;
      p2_inside         <= 1'b0;
      n_verts           <= 3'd0;
      min_x             <= 32'd0;
      max_x             <= 32'd0;
      min_y             <= 32'd0;
      max_y             <= 32'd0;
      for (i = 0; i < 8; i = i + 1) begin
        vx[i] <= 32'd0;
        vy[i] <= 32'd0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Load vertices
            n_verts <= num_vertices;
            for (i = 0; i < 8; i = i + 1) begin
              vx[i] <= vertices_x[i];
              vy[i] <= vertices_y[i];
            end
            // Initialize accumulators
            sum_accum        <= 48'd0;
            valid_sample_cnt <= 10'd0;
          end
        end

        S_INIT: begin
          // Compute bounding box from loaded vertices
          min_x <= vx[0];
          max_x <= vx[0];
          min_y <= vy[0];
          max_y <= vy[0];
          for (i = 1; i < 8; i = i + 1) begin
            if (i < n_verts) begin
              if (vx[i] < min_x) min_x <= vx[i];
              if (vx[i] > max_x) max_x <= vx[i];
              if (vy[i] < min_y) min_y <= vy[i];
              if (vy[i] > max_y) max_y <= vy[i];
            end
          end
        end

        S_GEN_P1: begin
          // Generate first random point in bounding box
          p1_x <= rand_in_range_q16_16(min_x, max_x, lfsr);
          p1_y <= rand_in_range_q16_16(min_y, max_y, {lfsr[3:0], lfsr[7:4]});
        end

        S_CHECK_P1: begin
          // Check if p1 is inside polygon
          p1_inside <= is_inside_convex(p1_x, p1_y, n_verts, vx, vy);
        end

        S_GEN_P2: begin
          // Generate second random point in bounding box
          p2_x <= rand_in_range_q16_16(min_x, max_x, ~lfsr);
          p2_y <= rand_in_range_q16_16(min_y, max_y, {~lfsr[3:0], ~lfsr[7:4]});
        end

        S_CHECK_P2: begin
          // Check if p2 is inside polygon
          p2_inside <= is_inside_convex(p2_x, p2_y, n_verts, vx, vy);
        end

        S_ACCUM: begin
          if (p1_inside && p2_inside) begin
            // Compute Manhattan distance
            manhattan_dist <= abs_diff32(p1_x, p2_x) + abs_diff32(p1_y, p2_y);
            sum_accum <= sum_accum + manhattan_dist;
            valid_sample_cnt <= valid_sample_cnt + 10'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // expected = sum / 1024 = sum >> 10
          expected <= sum_accum[47:16] >> 10; // align Q16.16 and divide
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_GEN_P1;
      end
      S_GEN_P1: begin
        next_state = S_CHECK_P1;
      end
      S_CHECK_P1: begin
        next_state = S_GEN_P2;
      end
      S_GEN_P2: begin
        next_state = S_CHECK_P2;
      end
      S_CHECK_P2: begin
        next_state = S_ACCUM;
      end
      S_ACCUM: begin
        if (valid_sample_cnt >= NUM_SAMPLES)
          next_state = S_DONE;
        else
          next_state = S_GEN_P1;
      end
      S_DONE: begin
        // Stay in DONE until start is deasserted then reasserted
        if (!start)
          next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule