module game_level_optimizer (
  input clk,
  input rst_n,
  input start,
  // Level 0
  input [1:0] x0,
  input [31:0] s0,
  input [31:0] a00,
  input [31:0] a01,
  input [31:0] a02,
  input [31:0] a03,
  // Level 1
  input [1:0] x1,
  input [31:0] s1,
  input [31:0] a10,
  input [31:0] a11,
  input [31:0] a12,
  input [31:0] a13,
  // Level 2
  input [1:0] x2,
  input [31:0] s2,
  input [31:0] a20,
  input [31:0] a21,
  input [31:0] a22,
  input [31:0] a23,
  output reg [31:0] min_time,
  output reg done
);

  function [31:0] min4;
    input [31:0] a, b, c, d;
    begin
      min4 = a;
      if (b < min4) min4 = b;
      if (c < min4) min4 = c;
      if (d < min4) min4 = d;
    end
  endfunction

  function [31:0] select_time;
    input [1:0] x;
    input [31:0] s;
    input [31:0] a0, a1, a2, a3;
    reg [31:0] items [0:3];
    begin
      items[0] = a0; items[1] = a1; items[2] = a2; items[3] = a3;
      select_time = (s < items[x]) ? s : items[x];
    end
  endfunction

  // Per-level best times (use shortcut if beneficial)
  wire [31:0] level_best [0:2];
  assign level_best[0] = select_time(x0, s0, a00, a01, a02, a03);
  assign level_best[1] = select_time(x1, s1, a10, a11, a12, a13);
  assign level_best[2] = select_time(x2, s2, a20, a21, a22, a23);

  // Compute total for all 6 permutations
  wire [31:0] t0 = level_best[0] + level_best[1] + level_best[2]; // 0,1,2
  wire [31:0] t1 = level_best[0] + level_best[2] + level_best[1]; // 0,2,1
  wire [31:0] t2 = level_best[1] + level_best[0] + level_best[2]; // 1,0,2
  wire [31:0] t3 = level_best[1] + level_best[2] + level_best[0]; // 1,2,0
  wire [31:0] t4 = level_best[2] + level_best[0] + level_best[1]; // 2,0,1
  wire [31:0] t5 = level_best[2] + level_best[1] + level_best[0]; // 2,1,0

  wire [31:0] min_overall;
  assign min_overall = min4(t0, t1, min4(t2, t3, t4, t5));

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_time <= 32'h0;
      done     <= 1'b0;
    end else begin
      if (start) begin
        min_time <= min_overall;  // Result valid 1 cycle after start
        done     <= 1'b1;         // done high for 1 cycle
      end else begin
        done     <= 1'b0;
      end
    end
  end

endmodule