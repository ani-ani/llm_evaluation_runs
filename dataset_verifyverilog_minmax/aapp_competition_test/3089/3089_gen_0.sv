module taxi_distance_calculator(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start calculation
  input [2:0] num_vertices, // number of polygon vertices (3-8)
  input [31:0] vertices_x [0:7], // Q16.16 x coordinates
  input [31:0] vertices_y [0:7], // Q16.16 y coordinates
  output reg [31:0] expected, // Q16.16 expected distance
  output reg done // high when calculation complete
);

  // Convex polygon point-in-polygon via same-side test (all cross products must have same sign)
  function signed [47:0] cross48 (input signed [31:0] ax, input signed [31:0] ay,
                                 input signed [31:0] bx, input signed [31:0] by);
    cross48 = $signed({ax, 16'b0}) * $signed({by, 16'b0}) - $signed({ay, 16'b0}) * $signed({bx, 16'b0});
  endfunction

  function bit inside_convex (input signed [31:0] px, input signed [31:0] py,
                              input [2:0] n, input bit [7:0] accept_collinear);
    integer i;
    signed [47:0] ref_cross;
    bit have_ref = 0;
    bit all_neg_or_zero = 1;
    bit all_pos_or_zero = 1;
    signed [31:0] ax, ay, bx, by, v0x, v0y;

    v0x = $signed(vertices_x[0]);
    v0y = $signed(vertices_y[0]);

    for (i = 0; i < 8; i = i + 1) begin
      if (i >= n) break;
      if (i == n - 1) begin
        ax = v0x; ay = v0y;
        bx = $signed(vertices_x[0]); by = $signed(vertices_y[0]);
      end else begin
        ax = $signed(vertices_x[i]); ay = $signed(vertices_y[i]);
        bx = $signed(vertices_x[i + 1]); by = $signed(vertices_y[i + 1]);
      end
      ref_cross = cross48(bx - ax, by - ay, px - ax, py - ay);
      if (!have_ref) begin
        have_ref = 1;
        if (accept_collinear) begin
          all_neg_or_zero = ref_cross <= 0;
          all_pos_or_zero = ref_cross >= 0;
        end else begin
          all_neg_or_zero = ref_cross < 0;
          all_pos_or_zero = ref_cross > 0;
        end
      end else begin
        if (accept_collinear) begin
          all_neg_or_zero = all_neg_or_zero && (ref_cross <= 0);
          all_pos_or_zero = all_pos_or_zero && (ref_cross >= 0);
        end else begin
          all_neg_or_zero = all_neg_or_zero && (ref_cross < 0);
          all_pos_or_zero = all_pos_or_zero && (ref_cross > 0);
        end
      end
    end
    inside_convex = (all_neg_or_zero || all_pos_or_zero);
  endfunction

  function bit inside_convex_collinear (input signed [31:0] px, input signed [31:0] py, input [2:0] n);
    inside_convex_collinear = inside_convex(px, py, n, 1'b1);
  endfunction

  function signed [31:0] manhattan_dist (input signed [31:0] x1, input signed [31:0] y1,
                                         input signed [31:0] x2, input signed [31:0] y2);
    manhattan_dist = (x1 >= x2 ? x1 - x2 : x2 - x1) + (y1 >= y2 ? y1 - y2 : y2 - y1);
  endfunction

  // 8-bit LFSR with 0x8E (X^8 + X^6 + X + 1) primitive taps
  reg [7:0] lfsr;
  wire [7:0] lfsr_next;
  assign lfsr_next = {lfsr[6:0], (lfsr[7] ^ lfsr[5] ^ lfsr[0]};

  // State machine
  typedef enum logic [2:0] { S_IDLE = 3'd0, S_INIT = 3'd1, S_SAMPLE_P1 = 3'd2, S_VERIFY_P1 = 3'd3,
                             S_SAMPLE_P2 = 3'd4, S_VERIFY_P2 = 3'd5, S_ACCUM = 3'd6, S_DONE = 3'd7 } state_t;
  state_t cur_state, nxt_state;

  // Bounding box in Q16.16
  reg signed [31:0] bb_min_x, bb_max_x, bb_min_y, bb_max_y;
  reg signed [31:0] range_x, range_y; // (max - min) in Q16.16
  reg [9:0] acc_valid;  // up to 1024
  reg [41:0] acc_sum;   // accumulate 1024 Q16.16 distances without overflow (max ~ 2^16 * 1024)

  // Point generation and verification in Q16.16
  reg signed [31:0] p1x, p1y, p2x, p2y;
  reg p1_valid, p2_valid;
  reg [2:0] n_vtx;
  reg [3:0] sample_counter; // lower 4 bits are enough for 1024 (2^10), we just need parity checks

  // Compute bounding box
  always @(*) begin
    integer k;
    bb_min_x = 32'h7fffffff; // +inf
    bb_max_x = 32'h80000000; // -inf
    bb_min_y = 32'h7fffffff;
    bb_max_y = 32'h80000000;
    for (k = 0; k < 8; k = k + 1) begin
      if (k < num_vertices) begin
        if ($signed(vertices_x[k]) < bb_min_x) bb_min_x = $signed(vertices_x[k]);
        if ($signed(vertices_x[k]) > bb_max_x) bb_max_x = $signed(vertices_x[k]);
        if ($signed(vertices_y[k]) < bb_min_y) bb_min_y = $signed(vertices_y[k]);
        if ($signed(vertices_y[k]) > bb_max_y) bb_max_y = $signed(vertices_y[k]);
      end
    end
    range_x = bb_max_x - bb_min_x; // Q16.16
    range_y = bb_max_y - bb_min_y; // Q16.16
  end

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cur_state <= S_IDLE;
      done <= 1'b0;
      expected <= 32'd0;
      lfsr <= 8'hFF; // nonzero seed
      p1_valid <= 1'b0;
      p2_valid <= 1'b0;
      acc_valid <= 10'd0;
      acc_sum <= 42'd0;
      sample_counter <= 4'd0;
      n_vtx <= 3'd0;
      p1x <= 32'd0; p1y <= 32'd0; p2x <= 32'd0; p2y <= 32'd0;
    end else begin
      cur_state <= nxt_state;
      case (nxt_state)
        S_IDLE: begin
          done <= 1'b0;
          expected <= 32'd0;
          acc_valid <= 10'd0;
          acc_sum <= 42'd0;
          sample_counter <= 4'd0;
          p1_valid <= 1'b0;
          p2_valid <= 1'b0;
        end
        S_INIT: begin
          n_vtx <= num_vertices;
          lfsr <= lfsr_next;
          p1_valid <= inside_convex_collinear(bb_min_x, bb_min_y, num_vertices);
          p1x <= bb_min_x; p1y <= bb_min_y;
          p2_valid <= 1'b0; // will compute on next state
        end
        S_SAMPLE_P1: begin
          lfsr <= lfsr_next;
          p1x <= bb_min_x + ( {16'b0, lfsr} * range_x >> 8 ); // scale to [0, range_x) in Q16.16
          p1y <= bb_min_y + ( {16'b0, lfsr_next} * range_y >> 8 );
        end
        S_VERIFY_P1: begin
          lfsr <= lfsr_next;
          p1_valid <= inside_convex_collinear(p1x, p1y, n_vtx);
        end
        S_SAMPLE_P2: begin
          lfsr <= lfsr_next;
          p2x <= bb_min_x + ( {16'b0, lfsr} * range_x >> 8 );
          p2y <= bb_min_y + ( {16'b0, lfsr_next} * range_y >> 8 );
        end
        S_VERIFY_P2: begin
          lfsr <= lfsr_next;
          p2_valid <= inside_convex_colconvex(p2x, p2y, n_vtx);
        end
        S_ACCUM: begin
          if (p1_valid && p2_valid) begin
            acc_sum <= acc_sum + manhattan_dist(p1x, p1y, p2x, p2y);
            acc_valid <= acc_valid + 1;
          end
        end
        S_DONE: begin
          done <= 1'b1;
          expected <= acc_sum >> 10; // average of 1024 valid pairs in Q16.16
        end
      endcase
    end
  end

  // FSM next-state logic
  always @(*) begin
    case (cur_state)
      S_IDLE:   nxt_state = start ? S_INIT : S_IDLE;
      S_INIT:   nxt_state = S_SAMPLE_P1;
      S_SAMPLE_P1: nxt_state = S_VERIFY_P1;
      S_VERIFY_P1: nxt_state = p1_valid ? S_SAMPLE_P1 : S_SAMPLE_P1; // resample if not valid
      S_SAMPLE_P2: nxt_state = S_VERIFY_P2;
      S_VERIFY_P2: nxt_state = p2_valid ? S_ACCUM : S_SAMPLE_P2;     // resample P2 if not valid
      S_ACCUM:  nxt_state = (acc_valid >= 10'd1023) ? S_DONE : S_SAMPLE_P1;
      S_DONE:   nxt_state = start ? S_DONE : S_IDLE; // restart when start is deasserted and reasserted
      default:  nxt_state = S_IDLE;
    endcase
  end

endmodule
