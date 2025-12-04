module dice_reroll_optimizer (
  input [2:0] K,
  input [5:0] T,
  input [17:0] first_roll,
  output reg [2:0] best_r
);

  // Die value extraction (0..6)
  wire [2:0] d0 = first_roll[2:0];
  wire [2:0] d1 = first_roll[5:3];
  wire [2:0] d2 = first_roll[8:6];
  wire [2:0] d3 = first_roll[11:9];
  wire [2:0] d4 = first_roll[14:12];
  wire [2:0] d5 = first_roll[17:15];

  // Sum of kept dice for a given mask (0..(1<<K)-1)
  function [6:0] compute_sum;
    input [2:0] K_in;
    input [2:0] d0, d1, d2, d3, d4, d5;
    input [5:0] mask; // LSB corresponds to keeping the die at position 0
    reg [6:0] sum;
    begin
      sum = 7'd0;
      if (mask[0] && K_in >= 3'd1) sum = sum + d0;
      if (mask[1] && K_in >= 3'd2) sum = sum + d1;
      if (mask[2] && K_in >= 3'd3) sum = sum + d2;
      if (mask[3] && K_in >= 3'd4) sum = sum + d3;
      if (mask[4] && K_in >= 3'd5) sum = sum + d4;
      if (mask[5] && K_in >= 3'd6) sum = sum + d5;
      compute_sum = sum;
    end
  endfunction

  // Precomputed rank(S, r) using case statements for r=0..6
  function [3:0] rank;
    input [5:0] S;
    input [2:0] r;
    begin
      case (r)
        3'd0: begin
          // Re-roll 0 dice: feasible only if T equals current kept sum; use S=T as proxy
          if (S == 6'd0) rank = 4'd15; else rank = 4'd0;
        end
        3'd1: begin
          case (S)
            6'd0, 6'd6: rank = 4'd1;
            6'd1, 6'd5: rank = 4'd4;
            6'd2, 6'd4: rank = 4'd8;
            6'd3:       rank = 4'd15;
            default:    rank = 4'd0;
          endcase
        end
        3'd2: begin
          case (S)
            6'd2, 6'd10, 6'd12: rank = 4'd1;
            6'd3, 6'd11:         rank = 4'd3;
            6'd4, 6'd8, 6'd9:    rank = 4'd6;
            6'd5, 6'd7:          rank = 4'd10;
            6'd6:                rank = 4'd14;
            default:             rank = 4'd0;
          endcase
        end
        3'd3: begin
          case (S)
            6'd3, 6'd15, 6'd18:   rank = 4'd1;
            6'd4, 6'd14, 6'd17:   rank = 4'd2;
            6'd5, 6'd13, 6'd16:   rank = 4'd4;
            6'd6, 6'd12:          rank = 4'd7;
            6'd7, 6'd11:          rank = 4'd10;
            6'd8, 6'd10:          rank = 4'd12;
            6'd9:                 rank = 4'd15;
            default:              rank = 4'd0;
          endcase
        end
        3'd4: begin
          case (S)
            6'd4, 6'd20, 6'd24:   rank = 4'd1;
            6'd5, 6'd23:          rank = 4'd2;
            6'd6, 6'd22:          rank = 4'd4;
            6'd7, 6'd21:          rank = 4'd6;
            6'd8, 6'd20:          rank = 4'd8;
            6'd9, 6'd19:          rank = 4'd10;
            6'd10,6'd18:          rank = 4'd12;
            6'd11,6'd17:          rank = 4'd13;
            6'd12,6'd16:          rank = 4'd14;
            6'd13,6'd15:          rank = 4'd15;
            6'd14:                rank = 4'd15;
            default:              rank = 4'd0;
          endcase
        end
        3'd5: begin
          case (S)
            6'd5, 6'd25, 6'd30:   rank = 4'd1;
            6'd6, 6'd29:          rank = 4'd2;
            6'd7, 6'd28:          rank = 4'd3;
            6'd8, 6'd27:          rank = 4'd5;
            6'd9, 6'd26:          rank = 4'd7;
            6'd10,6'd25:          rank = 4'd9;
            6'd11,6'd24:          rank = 4'd11;
            6'd12,6'd23:          rank = 4'd12;
            6'd13,6'd22:          rank = 4'd13;
            6'd14,6'd21:          rank = 4'd14;
            6'd15,6'd20:          rank = 4'd15;
            6'd16,6'd19:          rank = 4'd15;
            6'd17,6'd18:          rank = 4'd15;
            default:              rank = 4'd0;
          endcase
        end
        3'd6: begin
          case (S)
            6'd6, 6'd30, 6'd36:   rank = 4'd1;
            6'd7, 6'd35:          rank = 4'd2;
            6'd8, 6'd34:          rank = 4'd3;
            6'd9, 6'd33:          rank = 4'd4;
            6'd10,6'd32:          rank = 4'd5;
            6'd11,6'd31:          rank = 4'd6;
            6'd12,6'd30:          rank = 4'd7;
            6'd13,6'd29:          rank = 4'd8;
            6'd14,6'd28:          rank = 4'd9;
            6'd15,6'd27:          rank = 4'd10;
            6'd16,6'd26:          rank = 4'd11;
            6'd17,6'd25:          rank = 4'd12;
            6'd18,6'd24:          rank = 4'd13;
            6'd19,6'd23:          rank = 4'd14;
            6'd20,6'd22:          rank = 4'd15;
            6'd21:                rank = 4'd15;
            default:              rank = 4'd0;
          endcase
        end
        default: rank = 4'd0;
      endcase
    end
  endfunction

  integer r, mask, sum_keep, S_needed;
  integer best_score, r_score, best_r_local;

  always_comb begin
    best_score = -1;
    best_r_local = 0;
    // Evaluate each r from 0 to K (inclusive) to choose smallest r with highest score
    for (r = 0; r <= K; r = r + 1) begin
      r_score = 0;
      // Enumerate all combinations of which dice to keep (K-r kept, r re-rolled)
      for (mask = 0; mask < (1 << K); mask = mask + 1) begin
        // popcount(mask) must equal (K - r)
        if ($countones(mask) == (K - r)) begin
          sum_keep = compute_sum(K, d0, d1, d2, d3, d4, d5, mask);
          S_needed = T - sum_keep;
          if (S_needed >= r && S_needed <= (r * 6)) begin
            r_score = r_score + rank(S_needed, r[2:0]);
          end
        end
      end
      if (r_score > best_score) begin
        best_score = r_score;
        best_r_local = r;
      end
    end
    best_r = best_r_local[2:0];
  end

endmodule
