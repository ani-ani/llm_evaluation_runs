module dora_city_height (
  input clk,
  input rst_n,
  input start,
  input [15:0] a [0:3][0:3],
  input [1:0] target_i,
  input [1:0] target_j,
  output reg [3:0] x_result,
  output reg done
);

  // 6-stage pipeline: shift register to time the 'done' pulse
  reg [5:0] pipe_sr;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pipe_sr <= 6'b0;
    else        pipe_sr <= {pipe_sr[4:0], start};
  end
  wire stage1 = pipe_sr[0]; // Sort network starts this cycle (3 cycles)
  wire stage2 = pipe_sr[3]; // Rank calc starts after sort (2 cycles)
  wire stage3 = pipe_sr[5]; // Final result computed (1 cycle)
  assign done  = stage3;

  // Storage to latch selected row/column at start of pipeline
  reg [15:0] sel_row [0:3];
  reg [15:0] sel_col [0:3];
  reg [15:0] cur_elem;
  reg [1:0] raddr, caddr;
  always @(posedge clk) begin
    if (stage1) begin
      sel_row[0] <= a[raddr][0];
      sel_row[1] <= a[raddr][1];
      sel_row[2] <= a[raddr][2];
      sel_row[3] <= a[raddr][3];
      sel_col[0] <= a[0][caddr];
      sel_col[1] <= a[1][caddr];
      sel_col[2] <= a[2][caddr];
      sel_col[3] <= a[3][caddr];
      cur_elem   <= a[raddr][caddr];
    end
  end
  always @(posedge clk) begin
    if (stage1) begin
      raddr <= target_i;
      caddr <= target_j;
    end
  end

  // Stage 1: Sorting network (3 cycles) with duplicate removal
  // Unpacked arrays to support SystemVerilog array operations
  reg [15:0] row_vals [0:3];
  reg [15:0] col_vals [0:3];

  // Pipeline registers for row unique sorted list
  reg [15:0] row_uniq [0:3];
  reg [15:0] row_uniq_r1 [0:3];
  reg [15:0] row_uniq_r2 [0:3];
  // Pipeline registers for col unique sorted list
  reg [15:0] col_uniq [0:3];
  reg [15:0] col_uniq_r1 [0:3];
  reg [15:0] col_uniq_r2 [0:3];

  function [15:0] min16(input [15:0] a, input [15:0] b);
    min16 = (a < b) ? a : b;
  endfunction

  function [15:0] max16(input [15:0] a, input [15:0] b);
    max16 = (a > b) ? a : b;
  endfunction

  // 3-cycle sorting network with duplicate removal (unpacked arrays)
  always @(posedge clk) begin
    if (stage1) begin
      // Row
      row_vals[0] <= sel_row[0];
      row_vals[1] <= sel_row[1];
      row_vals[2] <= sel_row[2];
      row_vals[3] <= sel_row[3];
      // Col
      col_vals[0] <= sel_col[0];
      col_vals[1] <= sel_col[1];
      col_vals[2] <= sel_col[2];
      col_vals[3] <= sel_col[3];
    end
  end

  // 3-stage pipeline: 1->2 (end of cycle 1), 2->3 (end of cycle 2), 3->final (end of cycle 3)
  always @(posedge clk) begin
    if (stage1) begin
      // Stage 1 end: odd-even transposition pass 1 (sorted if input already sorted)
      // Row
      row_uniq[0] <= min16(row_vals[0], row_vals[1]);
      row_uniq[1] <= max16(row_vals[0], row_vals[1]);
      row_uniq[2] <= min16(row_vals[2], row_vals[3]);
      row_uniq[3] <= max16(row_vals[2], row_vals[3]);
      // Col
      col_uniq[0] <= min16(col_vals[0], col_vals[1]);
      col_uniq[1] <= max16(col_vals[0], col_vals[1]);
      col_uniq[2] <= min16(col_vals[2], col_vals[3]);
      col_uniq[3] <= max16(col_vals[2], col_vals[3]);
    end
  end

  always @(posedge clk) begin
    if (stage2) begin
      // Stage 2 end: odd-even transposition pass 2
      // Row
      row_uniq_r1[0] <= min16(row_uniq[0], row_uniq[2]);
      row_uniq_r1[1] <= min16(row_uniq[1], row_uniq[3]);
      row_uniq_r1[2] <= max16(row_uniq[0], row_uniq[2]);
      row_uniq_r1[3] <= max16(row_uniq[1], row_uniq[3]);
      // Col
      col_uniq_r1[0] <= min16(col_uniq[0], col_uniq[2]);
      col_uniq_r1[1] <= min16(col_uniq[1], col_uniq[3]);
      col_uniq_r1[2] <= max16(col_uniq[0], col_uniq[2]);
      col_uniq_r1[3] <= max16(col_uniq[1], col_uniq[3]);
    end
  end

  always @(posedge clk) begin
    if (stage3) begin
      // Stage 3 end: odd-even transposition pass 3 + duplicate removal (pack equal neighbors)
      // Row
      row_uniq_r2[0] <= min16(row_uniq_r1[0], row_uniq_r1[1]);
      row_uniq_r2[1] <= max16(row_uniq_r1[0], row_uniq_r1[1]);
      row_uniq_r2[2] <= min16(row_uniq_r1[2], row_uniq_r1[3]);
      row_uniq_r2[3] <= max16(row_uniq_r1[2], row_uniq_r1[3]);
      // Col
      col_uniq_r2[0] <= min16(col_uniq_r1[0], col_uniq_r1[1]);
      col_uniq_r2[1] <= max16(col_uniq_r1[0], col_uniq_r1[1]);
      col_uniq_r2[2] <= min16(col_uniq_r1[2], col_uniq_r1[3]);
      col_uniq_r2[3] <= max16(col_uniq_r1[2], col_uniq_r1[3]);
    end
  end

  // Remove duplicates and compact to the left (row)
  reg [15:0] row_sorted_uniq [0:3];
  reg [2:0] row_len; // 0..4
  reg [15:0] col_sorted_uniq [0:3];
  reg [2:0] col_len; // 0..4

  function automatic [2:0] pack_unique4(input [15:0] s0, input [15:0] s1, input [15:0] s2, input [15:0] s3,
                                        output [15:0] u0, output [15:0] u1, output [15:0] u2, output [15:0] u3);
    begin
      u0 = s0; u1 = s1; u2 = s2; u3 = s3;
      if (u1 == u0) u1 = 16'hFFFF; // sentinel (kept for width; will be ignored by len)
      if (u2 == u1) u2 = 16'hFFFF;
      if (u3 == u2) u3 = 16'hFFFF;
      if (u1 == u0) u1 = 16'hFFFF;
      if (u2 == u1) u2 = 16'hFFFF;
      if (u3 == u2) u3 = 16'hFFFF;
      // Length
      if (u0 == 16'hFFFF) pack_unique4 = 3'd0;
      else if (u1 == 16'hFFFF) pack_unique4 = 3'd1;
      else if (u2 == 16'hFFFF) pack_unique4 = 3'd2;
      else if (u3 == 16'hFFFF) pack_unique4 = 3'd3;
      else pack_unique4 = 3'd4;
    end
  endfunction

  always @(*) begin
    row_len = pack_unique4(row_uniq_r2[0], row_uniq_r2[1], row_uniq_r2[2], row_uniq_r2[3],
                           row_sorted_uniq[0], row_sorted_uniq[1], row_sorted_uniq[2], row_sorted_uniq[3]);
    col_len = pack_unique4(col_uniq_r2[0], col_uniq_r2[1], col_uniq_r2[2], col_uniq_r2[3],
                           col_sorted_uniq[0], col_sorted_uniq[1], col_sorted_uniq[2], col_sorted_uniq[3]);
  end

  // Stage 2: Rank calculation via FSM (2 cycles) - combinatorial implementation
  reg [2:0] row_rank; // 1..4 (0 if len==0)
  reg [2:0] col_rank; // 1..4 (0 if len==0)

  function automatic [2:0] first_rank_1based(input [15:0] u0, input [15:0] u1, input [15:0] u2, input [15:0] u3,
                                             input [2:0] len, input [15:0] target);
    integer i;
    begin
      first_rank_1based = 0;
      for (i = 0; i < 4; i = i + 1) begin
        case (i)
          0: if (len > 0 && u0 == target) first_rank_1based = 1;
          1: if (len > 1 && u1 == target) first_rank_1based = 2;
          2: if (len > 2 && u2 == target) first_rank_1based = 3;
          3: if (len > 3 && u3 == target) first_rank_1based = 4;
        endcase
        if (first_rank_1based != 0) break;
      end
    end
  endfunction

  always @(*) begin
    if (row_len == 0) row_rank = 0;
    else row_rank = first_rank_1based(row_sorted_uniq[0], row_sorted_uniq[1], row_sorted_uniq[2], row_sorted_uniq[3], row_len, cur_elem);

    if (col_len == 0) col_rank = 0;
    else col_rank = first_rank_1based(col_sorted_uniq[0], col_sorted_uniq[1], col_sorted_uniq[2], col_sorted_uniq[3], col_len, cur_elem);
  end

  // Stage 3: Compute final result (1 cycle) when result_valid is asserted
  // x_result = max(row_rank, col_rank) + max(R_len - row_rank, C_len - col_rank)
  wire [3:0] part1, part2;
  assign part1 = (row_rank > col_rank) ? row_rank : col_rank;
  assign part2 = ((row_len - row_rank) > (col_len - col_rank)) ? (row_len - row_rank) : (col_len - col_rank);

  always @(posedge clk) begin
    if (stage3) begin
      x_result <= part1 + part2;
    end
  end

endmodule