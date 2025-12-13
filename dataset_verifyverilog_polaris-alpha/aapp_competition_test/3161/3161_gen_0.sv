module josip_painter(
  input clk,
  input rst_n,
  input start,
  input [63:0] target_image,
  output reg [6:0] min_difference,
  output reg [63:0] output_image,
  output reg done
);

  // We implement Josip's painting as a fixed 8x8 recursive construction unrolled iteratively by levels.
  // Always treat input as 8x8; this satisfies N=1/2/4/8 as subcases inside 8x8 (padding in MSBs naturally ignored).
  // Painting rule (per Josip / quad-tree model):
  // - For 1x1 (k=0): choose pixel as target bit (zero cost).
  // - For larger squares: choose among
  //      * all white (all 1's)
  //      * all black (all 0's)
  //      * 4 quadrants individually chosen by their optimal painting (recursive)
  //    Pick option with minimal Hamming distance to target.

  // FSM states
  localparam S_IDLE   = 3'd0;
  localparam S_PREP   = 3'd1;
  localparam S_LVL1   = 3'd2; // 2x2 squares
  localparam S_LVL2   = 3'd3; // 4x4 squares
  localparam S_LVL3   = 3'd4; // 8x8 square
  localparam S_DONE   = 3'd5;

  reg [2:0] state, next_state;

  // Target bits as a convenient function
  function automatic bit tgt_bit;
    input [63:0] t;
    input int idx;
    begin
      tgt_bit = t[63-idx]; // MSB-first row-wise
    end
  endfunction

  // Level0 (1x1) painted image: always equals target (zero cost)
  // We don't store level0 explicitly; derived directly from target.

  // Level1: 2x2 blocks (16 blocks)
  // Storage per block: best image bits and cost (0..4)
  reg [3:0] lvl1_cost [0:15];
  reg [3:0] lvl1_img  [0:15]; // 4 bits per 2x2 block, MSB-first row-wise

  // Level2: 4x4 blocks (4 blocks)
  // Storage per block: 16-bit image and cost (0..16)
  reg [4:0]  lvl2_cost [0:3];
  reg [15:0] lvl2_img  [0:3];

  // Level3: 8x8 (1 block)
  reg [6:0] lvl3_cost;
  reg [63:0] lvl3_img;

  // Iterate indices for each level
  reg [4:0] idx1; // 0..15
  reg [2:0] idx2; // 0..3

  // Combinational helper: compute block best for 2x2
  task automatic compute_2x2_block;
    input  int base_row;
    input  int base_col;
    input  [63:0] timg;
    output [3:0] best_img;
    output [3:0] best_cost;
    integer r,c;
    integer idx_flat;
    reg [3:0] tgt4;
    integer ones_cnt;
    integer zeros_cnt;
    reg [3:0] white_cost;
    reg [3:0] black_cost;
    begin
      // Collect 4 target bits (row-wise, MSB-first inside block)
      tgt4 = 4'b0;
      for (r = 0; r < 2; r = r+1) begin
        for (c = 0; c < 2; c = c+1) begin
          idx_flat = (base_row + r)*8 + (base_col + c);
          tgt4[3 - (r*2 + c)] = tgt_bit(timg, idx_flat);
        end
      end

      ones_cnt  = tgt4[3] + tgt4[2] + tgt4[1] + tgt4[0];
      zeros_cnt = 4 - ones_cnt;

      white_cost = zeros_cnt[3:0]; // all 1's vs tgt
      black_cost = ones_cnt[3:0]; // all 0's vs tgt

      if (white_cost <= black_cost) begin
        best_cost = white_cost;
        best_img  = 4'b1111;
      end else begin
        best_cost = black_cost;
        best_img  = 4'b0000;
      end
    end
  endtask

  // Combinational helper for 4x4 from four 2x2
  task automatic compute_4x4_block;
    input  [3:0]  q_cost0;
    input  [3:0]  q_cost1;
    input  [3:0]  q_cost2;
    input  [3:0]  q_cost3;
    input  [3:0]  q_img0;
    input  [3:0]  q_img1;
    input  [3:0]  q_img2;
    input  [3:0]  q_img3;
    input  [63:0] timg;
    input  int base_row;
    input  int base_col;
    output [15:0] best_img;
    output [4:0]  best_cost;

    integer r,c;
    integer idx_flat;
    integer i;
    reg [15:0] tgt16;
    integer ones_cnt;
    integer zeros_cnt;
    reg [4:0] white_cost;
    reg [4:0] black_cost;
    reg [4:0] quad_cost;
    reg [15:0] quad_img;
    begin
      // Build tgt16
      tgt16 = 16'b0;
      for (r = 0; r < 4; r = r+1) begin
        for (c = 0; c < 4; c = c+1) begin
          idx_flat = (base_row + r)*8 + (base_col + c);
          tgt16[15 - (r*4 + c)] = tgt_bit(timg, idx_flat);
        end
      end

      // all white / all black cost
      ones_cnt = 0;
      for (i = 0; i < 16; i = i+1) begin
        ones_cnt = ones_cnt + tgt16[i];
      end
      zeros_cnt  = 16 - ones_cnt;
      white_cost = zeros_cnt[4:0];
      black_cost = ones_cnt[4:0];

      // quadrants from lvl1 results:
      // mapping: each 4x4 block is arranged as:
      //   q0 q1
      //   q2 q3
      // each q_img* is 2x2 MSB-first.
      quad_cost = q_cost0 + q_cost1 + q_cost2 + q_cost3;

      // compose quad_img in 4x4 layout
      quad_img = 16'b0;
      // q0 -> rows 0..1, cols 0..1
      quad_img[15 - (0*4 + 0)] = q_img0[3];
      quad_img[15 - (0*4 + 1)] = q_img0[2];
      quad_img[15 - (1*4 + 0)] = q_img0[1];
      quad_img[15 - (1*4 + 1)] = q_img0[0];
      // q1 -> rows 0..1, cols 2..3
      quad_img[15 - (0*4 + 2)] = q_img1[3];
      quad_img[15 - (0*4 + 3)] = q_img1[2];
      quad_img[15 - (1*4 + 2)] = q_img1[1];
      quad_img[15 - (1*4 + 3)] = q_img1[0];
      // q2 -> rows 2..3, cols 0..1
      quad_img[15 - (2*4 + 0)] = q_img2[3];
      quad_img[15 - (2*4 + 1)] = q_img2[2];
      quad_img[15 - (3*4 + 0)] = q_img2[1];
      quad_img[15 - (3*4 + 1)] = q_img2[0];
      // q3 -> rows 2..3, cols 2..3
      quad_img[15 - (2*4 + 2)] = q_img3[3];
      quad_img[15 - (2*4 + 3)] = q_img3[2];
      quad_img[15 - (3*4 + 2)] = q_img3[1];
      quad_img[15 - (3*4 + 3)] = q_img3[0];

      // choose best of {white, black, quad}
      best_cost = white_cost;
      best_img  = {16{1'b1}};

      if (black_cost < best_cost) begin
        best_cost = black_cost;
        best_img  = 16'b0;
      end

      if (quad_cost < best_cost) begin
        best_cost = quad_cost;
        best_img  = quad_img;
      end
    end
  endtask

  // Combinational helper for 8x8 from four 4x4
  task automatic compute_8x8_block;
    input  [4:0]  q_cost0;
    input  [4:0]  q_cost1;
    input  [4:0]  q_cost2;
    input  [4:0]  q_cost3;
    input  [15:0] q_img0;
    input  [15:0] q_img1;
    input  [15:0] q_img2;
    input  [15:0] q_img3;
    input  [63:0] timg;
    output [63:0] best_img;
    output [6:0]  best_cost;

    integer r,c;
    integer idx_flat;
    integer i;
    reg [63:0] tgt64;
    integer ones_cnt;
    integer zeros_cnt;
    reg [6:0] white_cost;
    reg [6:0] black_cost;
    reg [6:0] quad_cost;
    reg [63:0] quad_img;
    begin
      // tgt64 is just timg but we express for clarity
      tgt64 = timg;

      // all white / all black cost over 64 bits
      ones_cnt = 0;
      for (i = 0; i < 64; i = i+1) begin
        ones_cnt = ones_cnt + tgt64[i];
      end
      zeros_cnt  = 64 - ones_cnt;
      white_cost = zeros_cnt[6:0];
      black_cost = ones_cnt[6:0];

      // Quad-tree option
      quad_cost = q_cost0 + q_cost1 + q_cost2 + q_cost3;

      // compose quad_img:
      // Layout of 4x4 blocks (q0,q1; q2,q3). Each 4x4 is MSB-first.
      quad_img = 64'b0;
      // helper: copy 4x4 into 8x8 location
      // q0 at (0,0)
      for (r = 0; r < 4; r = r+1) begin
        for (c = 0; c < 4; c = c+1) begin
          quad_img[63 - ((0 + r)*8 + (0 + c))] = q_img0[15 - (r*4 + c)];
        end
      end
      // q1 at (0,4)
      for (r = 0; r < 4; r = r+1) begin
        for (c = 0; c < 4; c = c+1) begin
          quad_img[63 - ((0 + r)*8 + (4 + c))] = q_img1[15 - (r*4 + c)];
        end
      end
      // q2 at (4,0)
      for (r = 0; r < 4; r = r+1) begin
        for (c = 0; c < 4; c = c+1) begin
          quad_img[63 - ((4 + r)*8 + (0 + c))] = q_img2[15 - (r*4 + c)];
        end
      end
      // q3 at (4,4)
      for (r = 0; r < 4; r = r+1) begin
        for (c = 0; c < 4; c = c+1) begin
          quad_img[63 - ((4 + r)*8 + (4 + c))] = q_img3[15 - (r*4 + c)];
        end
      end

      // Select best among white, black, quad
      best_cost = white_cost;
      best_img  = {64{1'b1}};

      if (black_cost < best_cost) begin
        best_cost = black_cost;
        best_img  = 64'b0;
      end

      if (quad_cost < best_cost) begin
        best_cost = quad_cost;
        best_img  = quad_img;
      end
    end
  endtask

  // FSM next_state
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PREP;
      end
      S_PREP: begin
        next_state = S_LVL1;
      end
      S_LVL1: begin
        if (idx1 == 5'd15)
          next_state = S_LVL2;
      end
      S_LVL2: begin
        if (idx2 == 3'd3)
          next_state = S_LVL3;
      end
      S_LVL3: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential state/control and computations
  integer br, bc;
  integer blk;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      min_difference <= 7'd0;
      output_image <= 64'd0;
      idx1 <= 5'd0;
      idx2 <= 3'd0;
      lvl3_cost <= 7'd0;
      lvl3_img <= 64'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            idx1 <= 5'd0;
            idx2 <= 3'd0;
          end
        end

        S_PREP: begin
          // Nothing precomputed besides counters reset (already done)
          done <= 1'b0;
        end

        S_LVL1: begin
          // Process one 2x2 block per cycle using idx1
          // Map idx1 (0..15) to base_row, base_col (0,2,4,6)
          br = (idx1[4:2]) * 2; // idx1 / 4 * 2
          bc = (idx1[1:0]) * 2; // idx1 % 4 * 2

          begin : blk2x2
            reg [3:0] bimg;
            reg [3:0] bcost;
            compute_2x2_block(br, bc, target_image, bimg, bcost);
            lvl1_img[idx1]  <= bimg;
            lvl1_cost[idx1] <= bcost;
          end

          if (idx1 == 5'd15) begin
            idx1 <= 5'd0;
          end else begin
            idx1 <= idx1 + 5'd1;
          end
        end

        S_LVL2: begin
          // Process one 4x4 block per cycle using idx2 (0..3)
          // Each 4x4 composed from 4 corresponding 2x2 blocks
          // Layout of 4x4 blocks (idx2):
          // 0: rows 0..3, cols 0..3, uses lvl1 blocks (0,1,4,5)
          // 1: rows 0..3, cols 4..7, uses lvl1 blocks (2,3,6,7)
          // 2: rows 4..7, cols 0..3, uses lvl1 blocks (8,9,12,13)
          // 3: rows 4..7, cols 4..7, uses lvl1 blocks (10,11,14,15)

          begin : blk4x4
            reg [3:0]  c0; reg [3:0]  c1; reg [3:0]  c2; reg [3:0]  c3;
            reg [3:0]  i0; reg [3:0]  i1; reg [3:0]  i2; reg [3:0]  i3;
            reg [15:0] bimg;
            reg [4:0]  bcost;
            int base_r;
            int base_c;

            case (idx2)
              3'd0: begin
                c0 = lvl1_cost[0];  i0 = lvl1_img[0];
                c1 = lvl1_cost[1];  i1 = lvl1_img[1];
                c2 = lvl1_cost[4];  i2 = lvl1_img[4];
                c3 = lvl1_cost[5];  i3 = lvl1_img[5];
                base_r = 0; base_c = 0;
              end
              3'd1: begin
                c0 = lvl1_cost[2];  i0 = lvl1_img[2];
                c1 = lvl1_cost[3];  i1 = lvl1_img[3];
                c2 = lvl1_cost[6];  i2 = lvl1_img[6];
                c3 = lvl1_cost[7];  i3 = lvl1_img[7];
                base_r = 0; base_c = 4;
              end
              3'd2: begin
                c0 = lvl1_cost[8];  i0 = lvl1_img[8];
                c1 = lvl1_cost[9];  i1 = lvl1_img[9];
                c2 = lvl1_cost[12]; i2 = lvl1_img[12];
                c3 = lvl1_cost[13]; i3 = lvl1_img[13];
                base_r = 4; base_c = 0;
              end
              default: begin // 3
                c0 = lvl1_cost[10]; i0 = lvl1_img[10];
                c1 = lvl1_cost[11]; i1 = lvl1_img[11];
                c2 = lvl1_cost[14]; i2 = lvl1_img[14];
                c3 = lvl1_cost[15]; i3 = lvl1_img[15];
                base_r = 4; base_c = 4;
              end
            endcase

            compute_4x4_block(c0,c1,c2,c3,
                               i0,i1,i2,i3,
                               target_image,
                               base_r, base_c,
                               bimg, bcost);
            lvl2_img[idx2]  <= bimg;
            lvl2_cost[idx2] <= bcost;
          end

          if (idx2 == 3'd3) begin
            idx2 <= 3'd0;
          end else begin
            idx2 <= idx2 + 3'd1;
          end
        end

        S_LVL3: begin
          // Single 8x8 block from lvl2 (4x4 quadrants)
          begin : blk8x8
            reg [63:0] bimg;
            reg [6:0]  bcost;
            compute_8x8_block(
              lvl2_cost[0], lvl2_cost[1], lvl2_cost[2], lvl2_cost[3],
              lvl2_img[0],  lvl2_img[1],  lvl2_img[2],  lvl2_img[3],
              target_image,
              bimg, bcost
            );
            lvl3_img  <= bimg;
            lvl3_cost <= bcost;
          end
        end

        S_DONE: begin
          // Latch outputs
          done <= 1'b1;
          min_difference <= lvl3_cost;
          output_image   <= lvl3_img;
        end

        default: begin
        end
      endcase
    end
  end

endmodule