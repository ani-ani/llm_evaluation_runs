module partner_diversity(
  input clk,  // Clock signal
  input rst_n,  // Active-low reset
  input start,  // Start computation
  input [7:0] partner0_g, input [7:0] partner0_p, input [7:0] partner0_ga, input [7:0] partner0_pa,  // Partner 0 characteristics (0 when not awakenable)
  input [7:0] partner1_g, input [7:0] partner1_p, input [7:0] partner1_ga, input [7:0] partner1_pa,  // Partner 1 characteristics
  input [7:0] partner2_g, input [7:0] partner2_p, input [7:0] partner2_ga, input [7:0] partner2_pa,  // Partner 2 characteristics
  input [7:0] partner3_g, input [7:0] partner3_p, input [7:0] partner3_ga, input [7:0] partner3_pa,  // Partner 3 characteristics
  input [1:0] k,  // Maximum awakenings allowed (0-3)
  output reg [2:0] diversity,  // Result diversity (0-4)
  output reg done  // High when computation completes
);

  // Internal state machine and computation registers
  typedef enum logic [1:0] { IDLE = 2'b00, CALCULATING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  reg [4:0] cycle_cnt;    // Counts up to 20 cycles
  reg [3:0] comb;         // Current 4-bit combination (0..15)
  reg [1:0] bits_in_comb; // Number of set bits in comb
  reg [3:0] sel_vec;      // Selected partners (0..4)
  reg [2:0] max_diversity;

  // Helper functions (combinational)
  function [3:0] bitcount4(input [3:0] x);
    case (x)
      4'b0000: bitcount4 = 4'd0;
      4'b0001, 4'b0010, 4'b0100, 4'b1000: bitcount4 = 4'd1;
      4'b0011, 4'b0101, 4'b1001, 4'b0110, 4'b1010, 4'b1100: bitcount4 = 4'd2;
      4'b0111, 4'b1011, 4'b1101, 4'b1110: bitcount4 = 4'd3;
      4'b1111: bitcount4 = 4'd4;
      default: bitcount4 = 4'd0; // For completeness; should not hit
    endcase
  endfunction

  function [7:0] sel_g(input [3:0] sel, input [7:0] g0, input [7:0] g1, input [7:0] g2, input [7:0] g3);
    case (sel)
      4'b0001: sel_g = g0;
      4'b0010: sel_g = g1;
      4'b0100: sel_g = g2;
      4'b1000: sel_g = g3;
      default: sel_g = 8'd0;
    endcase
  endfunction

  function [7:0] sel_p(input [3:0] sel, input [7:0] p0, input [7:0] p1, input [7:0] p2, input [7:0] p3);
    case (sel)
      4'b0001: sel_p = p0;
      4'b0010: sel_p = p1;
      4'b0100: sel_p = p2;
      4'b1000: sel_p = p3;
      default: sel_p = 8'd0;
    endcase
  endfunction

  function [2:0] max_antichain_size(input [3:0] sel);
    reg [2:0] best;
    reg [2:0] i;
    reg [2:0] gi, gj;
    reg [2:0] pi, pj;
    reg dominates, valid;
    reg [3:0] sub;
    begin
      best = 3'd0;
      // Enumerate all subsets of 'sel'
      for (sub = 4'd0; sub < 4'd16; sub = sub + 4'd1) begin
        if ((sub & sel) != sub) continue; // sub must be subset of sel
        valid = 1'b1;
        for (i = 3'd0; (i < 3'd4) && valid; i = i + 3'd1) begin
          if (!sub[i]) continue;
          gi = sel_g({1'b0, i}, partner0_g, partner1_g, partner2_g, partner3_g);
          pi = sel_p({1'b0, i}, partner0_p, partner1_p, partner2_p, partner3_p);
          for (j = 3'd0; (j < 3'd4) && valid; j = j + 3'd1) begin
            if (i == j || !sub[j]) continue;
            gj = sel_g({1'b0, j}, partner0_g, partner1_g, partner2_g, partner3_g);
            pj = sel_p({1'b0, j}, partner0_p, partner1_p, partner2_p, partner3_p);
            // Dominance: both Frag and Step strictly greater
            dominates = (gi > gj) && (pi > pj);
            if (dominates) valid = 1'b0;
          end
        end
        if (valid) begin
          // Update best with size(sub)
          casez (sub)
            4'b???1, 4'b??10, 4'b?100, 4'b1000: best = 1;
            4'b0011, 4'b0101, 4'b1001, 4'b0110, 4'b1010, 4'b1100: best = (best < 2) ? 2 : best;
            4'b0111, 4'b1011, 4'b1101, 4'b1110: best = (best < 3) ? 3 : best;
            4'b1111: best = (best < 4) ? 4 : best;
            default: ;
          endcase
          if (sub == 4'd0) best = (best < 0) ? 0 : best; // Empty set is valid
        end
      end
      max_antichain_size = best;
    end
  endfunction

  // Compute diversity for the current valid combination (combinational across cycles)
  always @(*) begin
    if ((comb & ~k) == 4'd0) begin // valid awakening count <= k
      // Build selected partners vector: awakened use *_ga/_pa, not awakened use *_g/_p
      sel_vec = 4'd0;
      if (comb[0]) sel_vec[0] = 1'b1; else sel_vec[0] = 1'b0;
      if (comb[1]) sel_vec[1] = 1'b1; else sel_vec[1] = 1'b0;
      if (comb[2]) sel_vec[2] = 1'b1; else sel_vec[2] = 1'b0;
      if (comb[3]) sel_vec[3] = 1'b1; else sel_vec[3] = 1'b0;
      max_diversity = max_antichain_size(sel_vec);
    end else begin
      max_diversity = 3'd0;
    end
  end

  // State update (sequential)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 5'd0;
      comb <= 4'd0;
      diversity <= 3'd0;
      done <= 1'b1;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          cycle_cnt <= 5'd0;
          comb <= 4'd0;
          diversity <= 3'd0;
          done <= 1'b1;
        end
        CALCULATING: begin
          done <= 1'b0;
          diversity <= (max_diversity > diversity) ? max_diversity : diversity;
          cycle_cnt <= cycle_cnt + 5'd1;
          comb <= comb + 4'd1;
        end
        DONE: begin
          done <= 1'b1;
          cycle_cnt <= cycle_cnt;
          comb <= comb;
          diversity <= diversity;
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   next_state = start ? CALCULATING : IDLE;
      CALCULATING: next_state = (cycle_cnt == 5'd19) ? DONE : CALCULATING;
      DONE:   next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule
