module partner_diversity(
  input clk,  // Clock signal
  input rst_n,  // Active-low reset
  input start,  // Start computation
  input [7:0] partner0_g, input [7:0] partner0_p, input [7:0] partner0_ga, input [7:0] partner0_pa,
  input [7:0] partner1_g, input [7:0] partner1_p, input [7:0] partner1_ga, input [7:0] partner1_pa,
  input [7:0] partner2_g, input [7:0] partner2_p, input [7:0] partner2_ga, input [7:0] partner2_pa,
  input [7:0] partner3_g, input [7:0] partner3_p, input [7:0] partner3_ga, input [7:0] partner3_pa,
  input [1:0] k,  // Maximum awakenings allowed (0-3)
  output reg [2:0] diversity,  // Result diversity (0-4)
  output reg done  // High when computation completes
);

  // State encoding
  localparam IDLE        = 2'b00;
  localparam CALCULATING = 2'b01;
  localparam DONE        = 2'b10;

  reg [1:0] state, next_state;

  // Cycle counter to enforce 20-cycle latency
  reg [4:0] cycle_cnt;  // counts 0..19

  // Latched inputs to keep values stable during calculation
  reg [7:0] p_g [0:3];
  reg [7:0] p_p [0:3];
  reg [7:0] p_ga[0:3];
  reg [7:0] p_pa[0:3];
  reg [1:0] k_latched;

  // Internal best diversity result
  reg [2:0] best_diversity;

  // Combinational results for all subsets
  reg [2:0] subset_div [0:15];

  integer i;

  // Latch inputs on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p_g[0] <= 8'd0; p_p[0] <= 8'd0; p_ga[0] <= 8'd0; p_pa[0] <= 8'd0;
      p_g[1] <= 8'd0; p_p[1] <= 8'd0; p_ga[1] <= 8'd0; p_pa[1] <= 8'd0;
      p_g[2] <= 8'd0; p_p[2] <= 8'd0; p_ga[2] <= 8'd0; p_pa[2] <= 8'd0;
      p_g[3] <= 8'd0; p_p[3] <= 8'd0; p_ga[3] <= 8'd0; p_pa[3] <= 8'd0;
      k_latched <= 2'd0;
    end else if (state == IDLE && start) begin
      p_g[0] <= partner0_g; p_p[0] <= partner0_p; p_ga[0] <= partner0_ga; p_pa[0] <= partner0_pa;
      p_g[1] <= partner1_g; p_p[1] <= partner1_p; p_ga[1] <= partner1_ga; p_pa[1] <= partner1_pa;
      p_g[2] <= partner2_g; p_p[2] <= partner2_p; p_ga[2] <= partner2_ga; p_pa[2] <= partner2_pa;
      p_g[3] <= partner3_g; p_p[3] <= partner3_p; p_ga[3] <= partner3_ga; p_pa[3] <= partner3_pa;
      k_latched <= k;
    end
  end

  // State register and cycle counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 5'd0;
      best_diversity <= 3'd0;
      diversity <= 3'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          cycle_cnt <= 5'd0;
          best_diversity <= 3'd0;
          if (start) begin
            // computation will be done in CALCULATING combinationally
          end
        end

        CALCULATING: begin
          // Increment cycle counter, assert done and capture result on 20th cycle
          if (cycle_cnt == 5'd19) begin
            diversity <= best_diversity;
            done <= 1'b1;
          end else begin
            done <= 1'b0;
          end
          cycle_cnt <= cycle_cnt + 5'd1;
        end

        DONE: begin
          done <= 1'b1;
          // Hold diversity stable
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = CALCULATING;
        else
          next_state = IDLE;
      end
      CALCULATING: begin
        if (cycle_cnt == 5'd19)
          next_state = DONE;
        else
          next_state = CALCULATING;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
        else
          next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Function: count bits set in a 4-bit vector
  function automatic [2:0] popcount4(input [3:0] x);
    begin
      popcount4 = x[0] + x[1] + x[2] + x[3];
    end
  endfunction

  // Function: get (g,p) for a partner index and awaken bit
  function automatic [15:0] get_gp(
    input [1:0] idx,
    input       awaken,
    input [7:0] f_g0, input [7:0] f_p0, input [7:0] f_ga0, input [7:0] f_pa0,
    input [7:0] f_g1, input [7:0] f_p1, input [7:0] f_ga1, input [7:0] f_pa1,
    input [7:0] f_g2, input [7:0] f_p2, input [7:0] f_ga2, input [7:0] f_pa2,
    input [7:0] f_g3, input [7:0] f_p3, input [7:0] f_ga3, input [7:0] f_pa3
  );
    reg [7:0] g_sel, p_sel, ga_sel, pa_sel;
    begin
      case (idx)
        2'd0: begin g_sel = f_g0; p_sel = f_p0; ga_sel = f_ga0; pa_sel = f_pa0; end
        2'd1: begin g_sel = f_g1; p_sel = f_p1; ga_sel = f_ga1; pa_sel = f_pa1; end
        2'd2: begin g_sel = f_g2; p_sel = f_p2; ga_sel = f_ga2; pa_sel = f_pa2; end
        default: begin g_sel = f_g3; p_sel = f_p3; ga_sel = f_ga3; pa_sel = f_pa3; end
      endcase
      if (awaken) begin
        get_gp[15:8] = ga_sel;
        get_gp[7:0]  = pa_sel;
      end else begin
        get_gp[15:8] = g_sel;
        get_gp[7:0]  = p_sel;
      end
    end
  endfunction

  // Function: check if partner a dominates partner b
  // Dominance: ga > gb AND pa > pb
  function automatic dominates(
    input [7:0] ga, input [7:0] pa,
    input [7:0] gb, input [7:0] pb
  );
    begin
      dominates = (ga > gb) && (pa > pb);
    end
  endfunction

  // Function: compute diversity (size of largest subset with no dominance) for a given awaken mask
  function automatic [2:0] compute_diversity_for_mask(
    input [3:0] mask,
    input [7:0] f_g0, input [7:0] f_p0, input [7:0] f_ga0, input [7:0] f_pa0,
    input [7:0] f_g1, input [7:0] f_p1, input [7:0] f_ga1, input [7:0] f_pa1,
    input [7:0] f_g2, input [7:0] f_p2, input [7:0] f_ga2, input [7:0] f_pa2,
    input [7:0] f_g3, input [7:0] f_p3, input [7:0] f_ga3, input [7:0] f_pa3
  );
    reg [7:0] g [0:3];
    reg [7:0] p [0:3];
    integer i_local;
    reg [3:0] active_mask;
    reg [3:0] S;  // subset of active partners
    reg [2:0] max_size;
    reg valid;
    reg [2:0] size_S;
    integer a, b;
    reg [15:0] gp_val;

    begin
      // Build effective (g,p) based on awaken mask; if both normal and awakenable are zero, treat as unavailable via active_mask
      active_mask = 4'b0000;
      for (i_local = 0; i_local < 4; i_local = i_local + 1) begin
        gp_val = get_gp(i_local, mask[i_local],
                        f_g0, f_p0, f_ga0, f_pa0,
                        f_g1, f_p1, f_ga1, f_pa1,
                        f_g2, f_p2, f_ga2, f_pa2,
                        f_g3, f_p3, f_ga3, f_pa3);
        g[i_local] = gp_val[15:8];
        p[i_local] = gp_val[7:0];
        if (g[i_local] != 8'd0 || p[i_local] != 8'd0)
          active_mask[i_local] = 1'b1;
      end

      max_size = 3'd0;

      // Enumerate all subsets S of active partners (16 possibilities)
      for (S = 4'b0000; S < 4'b10000; S = S + 1) begin
        // S must be subset of active_mask
        if ((S & ~active_mask) != 4'b0000)
          continue;

        // Compute size of S
        size_S = popcount4(S);

        // Skip if cannot beat current max
        if (size_S <= max_size)
          continue;

        // Check if S has no dominance relations
        valid = 1'b1;
        for (a = 0; a < 4 && valid; a = a + 1) begin
          if (!S[a]) continue;
          for (b = 0; b < 4 && valid; b = b + 1) begin
            if (!S[b]) continue;
            if (a == b) continue;
            if (dominates(g[a], p[a], g[b], p[b])) begin
              valid = 1'b0;
            end
          end
        end

        if (valid && size_S > max_size)
          max_size = size_S;
      end

      compute_diversity_for_mask = max_size;
    end
  endfunction

  // Combinational evaluation of all masks and best_diversity update
  always @(*) begin
    reg [3:0] mask;
    reg [2:0] cnt;
    reg [2:0] cur_div;
    reg [2:0] best;

    best = 3'd0;

    // Evaluate all 16 awaken masks
    for (mask = 4'b0000; mask < 4'b10000; mask = mask + 1) begin
      cnt = popcount4(mask);
      if (cnt <= k_latched) begin
        cur_div = compute_diversity_for_mask(mask,
                    p_g[0], p_p[0], p_ga[0], p_pa[0],
                    p_g[1], p_p[1], p_ga[1], p_pa[1],
                    p_g[2], p_p[2], p_ga[2], p_pa[2],
                    p_g[3], p_p[3], p_ga[3], p_pa[3]);
        if (cur_div > best)
          best = cur_div;
      end
    end

    // Only actively drive best_diversity during CALCULATING; otherwise maintain previous via sequential logic
    if (state == CALCULATING || state == IDLE) begin
      // In IDLE after start, this will compute based on latched inputs
      // Assign to a shadow; registered in sequential always block
    end

    // Drive to a temporary wire-style reg, then captured in seq block via best_diversity
  end

  // Compute best_diversity registered once per cycle in CALCULATING/IDLE based on same combinational logic
  // To avoid recomputing, encapsulate in a separate always_comb block feeding a wire

  reg [2:0] best_div_comb;
  always @(*) begin
    reg [3:0] mask2;
    reg [2:0] cnt2;
    reg [2:0] cur_div2;
    reg [2:0] best2;

    best2 = 3'd0;
    for (mask2 = 4'b0000; mask2 < 4'b10000; mask2 = mask2 + 1) begin
      cnt2 = popcount4(mask2);
      if (cnt2 <= k_latched) begin
        cur_div2 = compute_diversity_for_mask(mask2,
                      p_g[0], p_p[0], p_ga[0], p_pa[0],
                      p_g[1], p_p[1], p_ga[1], p_pa[1],
                      p_g[2], p_p[2], p_ga[2], p_pa[2],
                      p_g[3], p_p[3], p_ga[3], p_pa[3]);
        if (cur_div2 > best2)
          best2 = cur_div2;
      end
    end
    best_div_comb = best2;
  end

  // Register best_diversity during CALCULATING (or when transitioning from IDLE after start)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      best_diversity <= 3'd0;
    end else begin
      if (state == IDLE && start) begin
        best_diversity <= best_div_comb;
      end else if (state == CALCULATING) begin
        best_diversity <= best_div_comb;
      end
    end
  end

endmodule