module dice_reroll_optimizer(input [2:0] K, input [5:0] T, input [17:0] first_roll, output reg [2:0] best_r);
  wire [2:0] dice [0:5];
  assign dice[0] = first_roll[2:0];
  assign dice[1] = first_roll[5:3];
  assign dice[2] = first_roll[8:6];
  assign dice[3] = first_roll[11:9];
  assign dice[4] = first_roll[14:12];
  assign dice[5] = first_roll[17:15];

  function automatic [31:0] get_rank(input [5:0] S, input [2:0] r);
    case(r)
      0: get_rank = (S == 0) ? 1 : 0;
      1: begin
        case(S)
          6'd1,6'd2,6'd3,6'd4,6'd5,6'd6: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      2: begin
        case(S)
          6'd2: get_rank = 1;
          6'd3: get_rank = 2;
          6'd4: get_rank = 3;
          6'd5: get_rank = 4;
          6'd6: get_rank = 5;
          6'd7: get_rank = 6;
          6'd8: get_rank = 5;
          6'd9: get_rank = 4;
          6'd10: get_rank = 3;
          6'd11: get_rank = 2;
          6'd12: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      3: begin
        case(S)
          6'd3: get_rank = 1;
          6'd4: get_rank = 3;
          6'd5: get_rank = 6;
          6'd6: get_rank = 10;
          6'd7: get_rank = 15;
          6'd8: get_rank = 21;
          6'd9: get_rank = 25;
          6'd10: get_rank = 27;
          6'd11: get_rank = 27;
          6'd12: get_rank = 25;
          6'd13: get_rank = 21;
          6'd14: get_rank = 15;
          6'd15: get_rank = 10;
          6'd16: get_rank = 6;
          6'd17: get_rank = 3;
          6'd18: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      4: begin
        case(S)
          6'd4: get_rank = 1;
          6'd5: get_rank = 4;
          6'd6: get_rank = 10;
          6'd7: get_rank = 20;
          6'd8: get_rank = 35;
          6'd9: get_rank = 56;
          6'd10: get_rank = 80;
          6'd11: get_rank = 104;
          6'd12: get_rank = 125;
          6'd13: get_rank = 140;
          6'd14: get_rank = 146;
          6'd15: get_rank = 140;
          6'd16: get_rank = 125;
          6'd17: get_rank = 104;
          6'd18: get_rank = 80;
          6'd19: get_rank = 56;
          6'd20: get_rank = 35;
          6'd21: get_rank = 20;
          6'd22: get_rank = 10;
          6'd23: get_rank = 4;
          6'd24: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      5: begin
        case(S)
          6'd5: get_rank = 1;
          6'd6: get_rank = 5;
          6'd7: get_rank = 15;
          6'd8: get_rank = 35;
          6'd9: get_rank = 70;
          6'd10: get_rank = 126;
          6'd11: get_rank = 205;
          6'd12: get_rank = 305;
          6'd13: get_rank = 420;
          6'd14: get_rank = 540;
          6'd15: get_rank = 651;
          6'd16: get_rank = 735;
          6'd17: get_rank = 780;
          6'd18: get_rank = 780;
          6'd19: get_rank = 735;
          6'd20: get_rank = 651;
          6'd21: get_rank = 540;
          6'd22: get_rank = 420;
          6'd23: get_rank = 305;
          6'd24: get_rank = 205;
          6'd25: get_rank = 126;
          6'd26: get_rank = 70;
          6'd27: get_rank = 35;
          6'd28: get_rank = 15;
          6'd29: get_rank = 5;
          6'd30: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      6: begin
        case(S)
          6'd6: get_rank = 1;
          6'd7: get_rank = 6;
          6'd8: get_rank = 21;
          6'd9: get_rank = 56;
          6'd10: get_rank = 126;
          6'd11: get_rank = 252;
          6'd12: get_rank = 456;
          6'd13: get_rank = 756;
          6'd14: get_rank = 1161;
          6'd15: get_rank = 1666;
          6'd16: get_rank = 2247;
          6'd17: get_rank = 2856;
          6'd18: get_rank = 3431;
          6'd19: get_rank = 3906;
          6'd20: get_rank = 4221;
          6'd21: get_rank = 4332;
          6'd22: get_rank = 4221;
          6'd23: get_rank = 3906;
          6'd24: get_rank = 3431;
          6'd25: get_rank = 2856;
          6'd26: get_rank = 2247;
          6'd27: get_rank = 1666;
          6'd28: get_rank = 1161;
          6'd29: get_rank = 756;
          6'd30: get_rank = 456;
          6'd31: get_rank = 252;
          6'd32: get_rank = 126;
          6'd33: get_rank = 56;
          6'd34: get_rank = 21;
          6'd35: get_rank = 6;
          6'd36: get_rank = 1;
          default: get_rank = 0;
        endcase
      end
      default: get_rank = 0;
    endcase
  endfunction

  reg [31:0] score [0:6];
  integer i, m;
  reg [5:0] mask;
  reg mask_valid;
  reg [5:0] subset_size;
  reg [5:0] subset_sum;
  reg [5:0] S_reroll;
  reg [31:0] current_rank;

  always_comb begin
    for (m = 0; m <= 6; m = m + 1) begin
      score[m] = 0;
    end

    for (i = 0; i < 64; i = i + 1) begin
      mask = i;
      mask_valid = 0;
      case(K)
        3'd2: mask_valid = (mask[5:2] == 4'b0);
        3'd3: mask_valid = (mask[5:3] == 3'b0);
        3'd4: mask_valid = (mask[5:4] == 2'b0);
        3'd5: mask_valid = (mask[5] == 1'b0);
        3'd6: mask_valid = 1'b1;
        default: mask_valid = 1'b0;
      endcase

      if (mask_valid) begin
        subset_size = 0;
        subset_sum = 0;
        for (m = 0; m < 6; m = m + 1) begin
          if (m < K && mask[m]) begin
            subset_size = subset_size + 1;
            subset_sum = subset_sum + dice[m];
          end
        end

        m = K - subset_size;
        if (m >= 0 && m <= 6) begin
          S_reroll = T - subset_sum;
          if (S_reroll >= m && S_reroll <= 6 * m) begin
            current_rank = get_rank(S_reroll, m);
            score[m] = score[m] + current_rank;
          end
        end
      end
    end

    best_r = 0;
    for (m = 0; m <= 6; m = m + 1) begin
      if (m <= K) begin
        if ((score[m] > score[best_r]) || (score[m] == score[best_r] && m < best_r)) begin
          best_r = m;
        end
      end
    end
  end
endmodule