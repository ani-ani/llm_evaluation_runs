module autocorrect_min_keystrokes(
  input clk,
  input rst_n,
  input start,
  input [7:0][39:0] dictionary,
  input [39:0] target_word,
  output reg [4:0] keystrokes,
  output reg done
);

  wire [4:0] target_chars [0:7];
  assign target_chars[0] = target_word[39:35];
  assign target_chars[1] = target_word[34:30];
  assign target_chars[2] = target_word[29:25];
  assign target_chars[3] = target_word[24:20];
  assign target_chars[4] = target_word[19:15];
  assign target_chars[5] = target_word[14:10];
  assign target_chars[6] = target_word[9:5];
  assign target_chars[7] = target_word[4:0];

  wire [2:0] target_length;
  assign target_length = 
    (target_chars[7]!=5'h1f) ? 3'd8 :
    (target_chars[6]!=5'h1f) ? 3'd7 :
    (target_chars[5]!=5'h1f) ? 3'd6 :
    (target_chars[4]!=5'h1f) ? 3'd5 :
    (target_chars[3]!=5'h1f) ? 3'd4 :
    (target_chars[2]!=5'h1f) ? 3'd3 :
    (target_chars[1]!=5'h1f) ? 3'd2 :
    (target_chars[0]!=5'h1f) ? 3'd1 : 3'd0;

  wire [2:0] dict_lengths [0:7];
  wire [4:0] dict_chars [0:7][0:7];

  genvar i, j;
  generate
    for (i=0; i<8; i++) begin: dict_words
      assign dict_chars[i][0] = dictionary[i][39:35];
      assign dict_chars[i][1] = dictionary[i][34:30];
      assign dict_chars[i][2] = dictionary[i][29:25];
      assign dict_chars[i][3] = dictionary[i][24:20];
      assign dict_chars[i][4] = dictionary[i][19:15];
      assign dict_chars[i][5] = dictionary[i][14:10];
      assign dict_chars[i][6] = dictionary[i][9:5];
      assign dict_chars[i][7] = dictionary[i][4:0];
      assign dict_lengths[i] = 
        (dict_chars[i][7]!=5'h1f) ? 3'd8 :
        (dict_chars[i][6]!=5'h1f) ? 3'd7 :
        (dict_chars[i][5]!=5'h1f) ? 3'd6 :
        (dict_chars[i][4]!=5'h1f) ? 3'd5 :
        (dict_chars[i][3]!=5'h1f) ? 3'd4 :
        (dict_chars[i][2]!=5'h1f) ? 3'd3 :
        (dict_chars[i][1]!=5'h1f) ? 3'd2 :
        (dict_chars[i][0]!=5'h1f) ? 3'd1 : 3'd0;
    end
  endgenerate

  wire [2:0] best_match_length [1:8];

  genvar p;
  generate
    for (p=1; p<=8; p++) begin: p_loop
      wire [2:0] word_match [0:7];
      for (i=0; i<8; i++) begin: word_matches
        wire [2:0] len_ip = (dict_lengths[i] < p) ? dict_lengths[i] : 3'(p);
        reg [2:0] lm;
        integer m, jj;
        always_comb begin
          lm = 0;
          for (m=len_ip; m>=1; m=m-1) begin
            reg match_found;
            match_found = 1'b1;
            for (jj=0; jj<m; jj=jj+1) begin
              if (dict_chars[i][jj] != target_chars[jj]) match_found = 0;
            end
            if (match_found) begin
              lm = 3'(m);
              break;
            end
          end
        end
        assign word_match[i] = lm;
      end

      wire [2:0] best_match_val;
      assign best_match_val = (word_match[7]>=word_match[6]) ? word_match[7] : word_match[6];
      wire [2:0] tmp1 = (best_match_val>=word_match[5]) ? best_match_val : word_match[5];
      wire [2:0] tmp2 = (tmp1>=word_match[4]) ? tmp1 : word_match[4];
      wire [2:0] tmp3 = (tmp2>=word_match[3]) ? tmp2 : word_match[3];
      wire [2:0] tmp4 = (tmp3>=word_match[2]) ? tmp3 : word_match[2];
      wire [2:0] tmp5 = (tmp4>=word_match[1]) ? tmp4 : word_match[1];
      wire [2:0] tmp6 = (tmp5>=word_match[0]) ? tmp5 : word_match[0];
      assign best_match_length[p] = tmp6;
    end
  endgenerate

  wire [4:0] dp [0:8];
  assign dp[0] = 5'd0;
  assign dp[1] = dp[0] + 1;
  assign dp[2] = dp[1] + 1;
  assign dp[3] = dp[2] + 1;
  assign dp[4] = dp[3] + 1;
  assign dp[5] = dp[4] + 1;
  assign dp[6] = dp[5] + 1;
  assign dp[7] = dp[6] + 1;
  assign dp[8] = dp[7] + 1;

  wire [4:0] candidate_cost [1:8];
  generate
    for (p=1; p<=8; p++) begin: candidate_gen
      wire valid = (p <= target_length) && (best_match_length[p] !=0);
      wire [4:0] cost = valid ? 
        (dp[p] + 1 + (3'(p) - best_match_length[p]) + (target_length - best_match_length[p])) :
        5'd31;
      assign candidate_cost[p] = cost;
    end
  endgenerate

  wire [4:0] min_candidate;
  wire [4:0] c01 = (candidate_cost[1] <= candidate_cost[2]) ? candidate_cost[1] : candidate_cost[2];
  wire [4:0] c23 = (candidate_cost[3] <= candidate_cost[4]) ? candidate_cost[3] : candidate_cost[4];
  wire [4:0] c45 = (candidate_cost[5] <= candidate_cost[6]) ? candidate_cost[5] : candidate_cost[6];
  wire [4:0] c67 = (candidate_cost[7] <= candidate_cost[8]) ? candidate_cost[7] : candidate_cost[8];
  wire [4:0] c0123 = (c01 <= c23) ? c01 : c23;
  wire [4:0] c4567 = (c45 <= c67) ? c45 : c67;
  wire [4:0] cand_min = (c0123 <= c4567) ? c0123 : c4567;

  wire [4:0] keystrokes_w = (dp[target_length] < cand_min) ? dp[target_length] : cand_min;

  reg [1:0] cnt;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 2'b00;
      done <= 1'b0;
      keystrokes <= 5'd0;
    end else begin
      case (cnt)
        2'b00: begin
          if (start) cnt <= 2'b01;
          done <= 1'b0;
        end
        2'b01: cnt <= 2'b10;
        2'b10: cnt <= 2'b11;
        2'b11: begin
          keystrokes <= keystrokes_w;
          done <= 1'b1;
          cnt <= 2'b00;
        end
      endcase
    end
  end

endmodule