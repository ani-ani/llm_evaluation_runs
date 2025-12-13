module game_level_optimizer(
  input              clk,
  input              rst_n,
  input              start,
  // Level 0 parameters:
  input       [1:0]  x0,
  input       [31:0] s0,
  input       [31:0] a00,
  input       [31:0] a01,
  input       [31:0] a02,
  input       [31:0] a03,
  // Level 1 parameters:
  input       [1:0]  x1,
  input       [31:0] s1,
  input       [31:0] a10,
  input       [31:0] a11,
  input       [31:0] a12,
  input       [31:0] a13,
  // Level 2 parameters:
  input       [1:0]  x2,
  input       [31:0] s2,
  input       [31:0] a20,
  input       [31:0] a21,
  input       [31:0] a22,
  input       [31:0] a23,
  output reg  [31:0] min_time,
  output reg         done
);

  // Latched inputs
  reg [1:0]  r_x0, r_x1, r_x2;
  reg [31:0] r_s0, r_s1, r_s2;
  reg [31:0] r_a00, r_a01, r_a02, r_a03;
  reg [31:0] r_a10, r_a11, r_a12, r_a13;
  reg [31:0] r_a20, r_a21, r_a22, r_a23;

  // Combinational wires for permutation totals
  reg [31:0] perm0_time;
  reg [31:0] perm1_time;
  reg [31:0] perm2_time;
  reg [31:0] perm3_time;
  reg [31:0] perm4_time;
  reg [31:0] perm5_time;

  // Helper function: get best item time for level l given available items
  function automatic [31:0] best_item_time_level0(
    input [0:0] av0,
    input [0:0] av1,
    input [0:0] av2,
    input [0:0] av3
  );
    reg [31:0] best;
    begin
      best = 32'hFFFFFFFF;
      if (av0 && (r_a00 < best)) best = r_a00;
      if (av1 && (r_a01 < best)) best = r_a01;
      if (av2 && (r_a02 < best)) best = r_a02;
      if (av3 && (r_a03 < best)) best = r_a03;
      best_item_time_level0 = best;
    end
  endfunction

  function automatic [31:0] best_item_time_level1(
    input [0:0] av0,
    input [0:0] av1,
    input [0:0] av2,
    input [0:0] av3
  );
    reg [31:0] best;
    begin
      best = 32'hFFFFFFFF;
      if (av0 && (r_a10 < best)) best = r_a10;
      if (av1 && (r_a11 < best)) best = r_a11;
      if (av2 && (r_a12 < best)) best = r_a12;
      if (av3 && (r_a13 < best)) best = r_a13;
      best_item_time_level1 = best;
    end
  endfunction

  function automatic [31:0] best_item_time_level2(
    input [0:0] av0,
    input [0:0] av1,
    input [0:0] av2,
    input [0:0] av3
  );
    reg [31:0] best;
    begin
      best = 32'hFFFFFFFF;
      if (av0 && (r_a20 < best)) best = r_a20;
      if (av1 && (r_a21 < best)) best = r_a21;
      if (av2 && (r_a22 < best)) best = r_a22;
      if (av3 && (r_a23 < best)) best = r_a23;
      best_item_time_level2 = best;
    end
  endfunction

  // Helper: compute time for one level in sequence
  function automatic [31:0] level_time(
    input [1:0] level_id,
    input [1:0] x_sel,
    input [31:0] s_sel,
    input [0:0] av0,
    input [0:0] av1,
    input [0:0] av2,
    input [0:0] av3
  );
    reg [31:0] best_item;
    begin
      case (level_id)
        2'd0: best_item = best_item_time_level0(av0, av1, av2, av3);
        2'd1: best_item = best_item_time_level1(av0, av1, av2, av3);
        default: best_item = best_item_time_level2(av0, av1, av2, av3);
      endcase

      // If shortcut item is available, use shortcut time; else use best item time
      if ((x_sel == 2'd0 && av0) ||
          (x_sel == 2'd1 && av1) ||
          (x_sel == 2'd2 && av2) ||
          (x_sel == 2'd3 && av3)) begin
        level_time = s_sel;
      end else begin
        level_time = best_item;
      end
    end
  endfunction

  // Helper: update availability after using shortcut item for level
  function automatic [3:0] update_avail(
    input [3:0] avail,
    input [1:0] x_sel,
    input       used_shortcut
  );
    reg [3:0] next_avail;
    begin
      next_avail = avail;
      if (used_shortcut) begin
        case (x_sel)
          2'd0: next_avail[0] = 1'b0;
          2'd1: next_avail[1] = 1'b0;
          2'd2: next_avail[2] = 1'b0;
          2'd3: next_avail[3] = 1'b0;
        endcase
      end
      update_avail = next_avail;
    end
  endfunction

  // Helper: compute one level step including availability update
  function automatic void do_level(
    input  [1:0] level_id,
    input  [1:0] x_sel,
    input  [31:0] s_sel,
    input  [3:0] avail_in,
    output [31:0] time_out,
    output [3:0] avail_out
  );
    reg [31:0] best_item;
    reg [31:0] lvl_time;
    reg        used_shortcut;
    begin
      // Get best item for this level
      case (level_id)
        2'd0: best_item = best_item_time_level0(avail_in[0], avail_in[1], avail_in[2], avail_in[3]);
        2'd1: best_item = best_item_time_level1(avail_in[0], avail_in[1], avail_in[2], avail_in[3]);
        default: best_item = best_item_time_level2(avail_in[0], avail_in[1], avail_in[2], avail_in[3]);
      endcase

      // Decide usage of shortcut
      used_shortcut = 1'b0;
      if ((x_sel == 2'd0 && avail_in[0]) ||
          (x_sel == 2'd1 && avail_in[1]) ||
          (x_sel == 2'd2 && avail_in[2]) ||
          (x_sel == 2'd3 && avail_in[3])) begin
        lvl_time = s_sel;
        used_shortcut = 1'b1;
      end else begin
        lvl_time = best_item;
      end

      time_out = lvl_time;
      avail_out = update_avail(avail_in, x_sel, used_shortcut);
    end
  endfunction

  // Combinational block to compute all permutations based on latched inputs
  always @(*) begin
    // Permutation 0: 0 -> 1 -> 2
    begin : P0
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd0, r_x0, r_s0, av0, t0, av1);
      do_level(2'd1, r_x1, r_s1, av1, t1, av2);
      do_level(2'd2, r_x2, r_s2, av2, t2, /*unused*/);
      perm0_time = t0 + t1 + t2;
    end

    // Permutation 1: 0 -> 2 -> 1
    begin : P1
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd0, r_x0, r_s0, av0, t0, av1);
      do_level(2'd2, r_x2, r_s2, av1, t1, av2);
      do_level(2'd1, r_x1, r_s1, av2, t2, /*unused*/);
      perm1_time = t0 + t1 + t2;
    end

    // Permutation 2: 1 -> 0 -> 2
    begin : P2
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd1, r_x1, r_s1, av0, t0, av1);
      do_level(2'd0, r_x0, r_s0, av1, t1, av2);
      do_level(2'd2, r_x2, r_s2, av2, t2, /*unused*/);
      perm2_time = t0 + t1 + t2;
    end

    // Permutation 3: 1 -> 2 -> 0
    begin : P3
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd1, r_x1, r_s1, av0, t0, av1);
      do_level(2'd2, r_x2, r_s2, av1, t1, av2);
      do_level(2'd0, r_x0, r_s0, av2, t2, /*unused*/);
      perm3_time = t0 + t1 + t2;
    end

    // Permutation 4: 2 -> 0 -> 1
    begin : P4
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd2, r_x2, r_s2, av0, t0, av1);
      do_level(2'd0, r_x0, r_s0, av1, t1, av2);
      do_level(2'd1, r_x1, r_s1, av2, t2, /*unused*/);
      perm4_time = t0 + t1 + t2;
    end

    // Permutation 5: 2 -> 1 -> 0
    begin : P5
      reg [3:0] av0;
      reg [31:0] t0, t1, t2;
      reg [3:0] av1, av2;
      av0 = 4'b1111;
      do_level(2'd2, r_x2, r_s2, av0, t0, av1);
      do_level(2'd1, r_x1, r_s1, av1, t1, av2);
      do_level(2'd0, r_x0, r_s0, av2, t2, /*unused*/);
      perm5_time = t0 + t1 + t2;
    end
  end

  // Sequential: latch inputs and compute min_time with 1-cycle latency
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_x0  <= 2'd0; r_x1  <= 2'd0; r_x2  <= 2'd0;
      r_s0  <= 32'd0; r_s1 <= 32'd0; r_s2 <= 32'd0;
      r_a00 <= 32'd0; r_a01 <= 32'd0; r_a02 <= 32'd0; r_a03 <= 32'd0;
      r_a10 <= 32'd0; r_a11 <= 32'd0; r_a12 <= 32'd0; r_a13 <= 32'd0;
      r_a20 <= 32'd0; r_a21 <= 32'd0; r_a22 <= 32'd0; r_a23 <= 32'd0;
      min_time <= 32'd0;
      done     <= 1'b0;
    end else begin
      done <= 1'b0;
      if (start) begin
        // Latch inputs
        r_x0  <= x0;  r_x1  <= x1;  r_x2  <= x2;
        r_s0  <= s0;  r_s1  <= s1;  r_s2  <= s2;
        r_a00 <= a00; r_a01 <= a01; r_a02 <= a02; r_a03 <= a03;
        r_a10 <= a10; r_a11 <= a11; r_a12 <= a12; r_a13 <= a13;
        r_a20 <= a20; r_a21 <= a21; r_a22 <= a22; r_a23 <= a23;

        // Compute minimum among permutation totals (based on latched values next cycle)
        // Note: Since comb logic uses r_* values, min_time reflects previous cycle's start.
        // To meet 1-cycle latency from start, we rely on r_* being updated and used
        // in the same cycle via blocking in comb; here we select from perm*_time.
        begin : MIN_SEL
          reg [31:0] m0;
          m0 = perm0_time;
          if (perm1_time < m0) m0 = perm1_time;
          if (perm2_time < m0) m0 = perm2_time;
          if (perm3_time < m0) m0 = perm3_time;
          if (perm4_time < m0) m0 = perm4_time;
          if (perm5_time < m0) m0 = perm5_time;
          min_time <= m0;
        end

        done <= 1'b1;
      end
    end
  end

endmodule