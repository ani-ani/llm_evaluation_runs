module dice_reroll_optimizer(
  input  [2:0]  K,
  input  [5:0]  T,
  input  [17:0] first_roll,
  output reg [2:0] best_r
);

  // Extract dice values (3-bit each). If K < 6, unused dice values are ignored.
  wire [2:0] d0 = first_roll[2:0];
  wire [2:0] d1 = first_roll[5:3];
  wire [2:0] d2 = first_roll[8:6];
  wire [2:0] d3 = first_roll[11:9];
  wire [2:0] d4 = first_roll[14:12];
  wire [2:0] d5 = first_roll[17:15];

  // Rank function: returns an integer score approximating probability for sum S with r dice.
  // Implemented as a function with case statements, combinational.
  function automatic [15:0] rank;
    input [5:0] S;
    input [2:0] r;
    begin
      case (r)
        3'd0: begin
          // No dice re-rolled: only exact S=0 is meaningful as placeholder; real usage: only S=T-sum_keep, with r=0.
          // We define high score if S==0 (target already met), else 0.
          case (S)
            6'd0: rank = 16'd10000;
            default: rank = 16'd0;
          endcase
        end

        3'd1: begin
          // One die: valid S in [1..6]. Use simple increasing weights (placeholder for probability-based ranking).
          case (S)
            6'd1: rank = 16'd10;
            6'd2: rank = 16'd20;
            6'd3: rank = 16'd30;
            6'd4: rank = 16'd40;
            6'd5: rank = 16'd50;
            6'd6: rank = 16'd60;
            default: rank = 16'd0;
          endcase
        end

        3'd2: begin
          // Two dice: S in [2..12]. Use triangle-like distribution as rank (counts of combinations).
          case (S)
            6'd2:  rank = 16'd1;
            6'd3:  rank = 16'd2;
            6'd4:  rank = 16'd3;
            6'd5:  rank = 16'd4;
            6'd6:  rank = 16'd5;
            6'd7:  rank = 16'd6;
            6'd8:  rank = 16'd5;
            6'd9:  rank = 16'd4;
            6'd10: rank = 16'd3;
            6'd11: rank = 16'd2;
            6'd12: rank = 16'd1;
            default: rank = 16'd0;
          endcase
        end

        3'd3: begin
          // Three dice: S in [3..18]. Approximate with known counts.
          case (S)
            6'd3:  rank = 16'd1;
            6'd4:  rank = 16'd3;
            6'd5:  rank = 16'd6;
            6'd6:  rank = 16'd10;
            6'd7:  rank = 16'd15;
            6'd8:  rank = 16'd21;
            6'd9:  rank = 16'd25;
            6'd10: rank = 16'd27;
            6'd11: rank = 16'd27;
            6'd12: rank = 16'd25;
            6'd13: rank = 16'd21;
            6'd14: rank = 16'd15;
            6'd15: rank = 16'd10;
            6'd16: rank = 16'd6;
            6'd17: rank = 16'd3;
            6'd18: rank = 16'd1;
            default: rank = 16'd0;
          endcase
        end

        3'd4: begin
          // Four dice: S in [4..24]. Approximate distribution.
          case (S)
            6'd4:  rank = 16'd1;
            6'd5:  rank = 16'd4;
            6'd6:  rank = 16'd10;
            6'd7:  rank = 16'd20;
            6'd8:  rank = 16'd35;
            6'd9:  rank = 16'd56;
            6'd10: rank = 16'd80;
            6'd11: rank = 16'd104;
            6'd12: rank = 16'd125;
            6'd13: rank = 16'd140;
            6'd14: rank = 16'd146;
            6'd15: rank = 16'd140;
            6'd16: rank = 16'd125;
            6'd17: rank = 16'd104;
            6'd18: rank = 16'd80;
            6'd19: rank = 16'd56;
            6'd20: rank = 16'd35;
            6'd21: rank = 16'd20;
            6'd22: rank = 16'd10;
            6'd23: rank = 16'd4;
            6'd24: rank = 16'd1;
            default: rank = 16'd0;
          endcase
        end

        3'd5: begin
          // Five dice: S in [5..30]. Approximate, monotonic-like.
          // Values chosen to be combinationally simple and smoothly distributed.
          case (S)
            6'd5:  rank = 16'd1;
            6'd6:  rank = 16'd5;
            6'd7:  rank = 16'd15;
            6'd8:  rank = 16'd35;
            6'd9:  rank = 16'd70;
            6'd10: rank = 16'd126;
            6'd11: rank = 16'd205;
            6'd12: rank = 16'd305;
            6'd13: rank = 16'd420;
            6'd14: rank = 16'd540;
            6'd15: rank = 16'd651;
            6'd16: rank = 16'd735;
            6'd17: rank = 16'd780;
            6'd18: rank = 16'd780;
            6'd19: rank = 16'd735;
            6'd20: rank = 16'd651;
            6'd21: rank = 16'd540;
            6'd22: rank = 16'd420;
            6'd23: rank = 16'd305;
            6'd24: rank = 16'd205;
            6'd25: rank = 16'd126;
            6'd26: rank = 16'd70;
            6'd27: rank = 16'd35;
            6'd28: rank = 16'd15;
            6'd29: rank = 16'd5;
            6'd30: rank = 16'd1;
            default: rank = 16'd0;
          endcase
        end

        3'd6: begin
          // Six dice: S in [6..36]. Approximate smooth distribution.
          case (S)
            6'd6:  rank = 16'd1;
            6'd7:  rank = 16'd6;
            6'd8:  rank = 16'd21;
            6'd9:  rank = 16'd56;
            6'd10: rank = 16'd126;
            6'd11: rank = 16'd252;
            6'd12: rank = 16'd462;
            6'd13: rank = 16'd792;
            6'd14: rank = 16'd1287;
            6'd15: rank = 16'd2002;
            6'd16: rank = 16'd3003;
            6'd17: rank = 16'd4368;
            6'd18: rank = 16'd6188;
            6'd19: rank = 16'd8568;
            6'd20: rank = 16'd11628;
            6'd21: rank = 16'd15504;
            6'd22: rank = 16'd15504;
            6'd23: rank = 16'd11628;
            6'd24: rank = 16'd8568;
            6'd25: rank = 16'd6188;
            6'd26: rank = 16'd4368;
            6'd27: rank = 16'd3003;
            6'd28: rank = 16'd2002;
            6'd29: rank = 16'd1287;
            6'd30: rank = 16'd792;
            6'd31: rank = 16'd462;
            6'd32: rank = 16'd252;
            6'd33: rank = 16'd126;
            6'd34: rank = 16'd56;
            6'd35: rank = 16'd21;
            6'd36: rank = 16'd6;
            default: rank = 16'd0;
          endcase
        end

        default: begin
          rank = 16'd0;
        end
      endcase
    end
  endfunction

  // Helper: compute sum_keep for a given mask and K.
  function automatic [6:0] sum_keep_mask;
    input [5:0] mask;
    input [2:0] K_in;
    reg [6:0] s;
    begin
      s = 7'd0;
      if (K_in > 0 && mask[0]) s = s + d0;
      if (K_in > 1 && mask[1]) s = s + d1;
      if (K_in > 2 && mask[2]) s = s + d2;
      if (K_in > 3 && mask[3]) s = s + d3;
      if (K_in > 4 && mask[4]) s = s + d4;
      if (K_in > 5 && mask[5]) s = s + d5;
      sum_keep_mask = s;
    end
  endfunction

  // Helper: count bits in mask limited to first K bits.
  function automatic [2:0] popcountK;
    input [5:0] mask;
    input [2:0] K_in;
    reg [2:0] c;
    begin
      c = 3'd0;
      if (K_in > 0 && mask[0]) c = c + 3'd1;
      if (K_in > 1 && mask[1]) c = c + 3'd1;
      if (K_in > 2 && mask[2]) c = c + 3'd1;
      if (K_in > 3 && mask[3]) c = c + 3'd1;
      if (K_in > 4 && mask[4]) c = c + 3'd1;
      if (K_in > 5 && mask[5]) c = c + 3'd1;
      popcountK = c;
    end
  endfunction

  // Main combinational block: evaluate scores for r = 0..K and select best.
  integer i;
  reg [15:0] r_score [0:6];
  reg [15:0] best_score;
  reg [2:0]  best_r_int;

  always @* begin
    // Initialize scores for all r to 0.
    r_score[0] = 16'd0;
    r_score[1] = 16'd0;
    r_score[2] = 16'd0;
    r_score[3] = 16'd0;
    r_score[4] = 16'd0;
    r_score[5] = 16'd0;
    r_score[6] = 16'd0;

    // Iterate over all subsets of up to 6 dice. Only the lowest K bits are meaningful.
    // For each subset ("keep" mask), determine r = K - kept, compute S = T - sum_keep, and add rank(S,r).
    for (i = 0; i < 64; i = i + 1) begin
      reg [5:0] mask;
      reg [2:0] kept;
      reg [2:0] r_local;
      reg [6:0] sum_keep;
      reg [6:0] S_req;
      reg [15:0] rk;

      mask = i[5:0];
      // Restrict keeps to first K dice only via popcountK.
      kept = popcountK(mask, K);
      // Ensure no bits beyond K are considered as kept (popcountK already enforces via K limit).
      // Re-rolled dice count:
      if (K >= kept)
        r_local = K - kept;
      else
        r_local = 3'd7; // invalid sentinel

      if (r_local <= 3'd6) begin
        sum_keep = sum_keep_mask(mask, K);
        // Required sum from rerolled dice
        if (T >= sum_keep)
          S_req = T - sum_keep;
        else
          S_req = 7'd127; // impossible

        // Only accumulate if 0 <= r_local <= K and S_req is in [r_local .. 6*r_local]
        if ((r_local <= K) && (S_req >= r_local) && (S_req <= (r_local * 6))) begin
          rk = rank(S_req[5:0], r_local);
          r_score[r_local] = r_score[r_local] + rk;
        end
      end
    end

    // Select smallest r with highest score.
    best_score = 16'd0;
    best_r_int = 3'd0;

    // r ranges from 0 to K; others remain 0 and are ignored by condition.
    for (i = 0; i <= 6; i = i + 1) begin
      if (i <= K) begin
        if (r_score[i[2:0]] > best_score) begin
          best_score = r_score[i[2:0]];
          best_r_int = i[2:0];
        end
      end
    end

    best_r = best_r_int;
  end

endmodule