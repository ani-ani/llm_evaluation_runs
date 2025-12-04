module haiku_formatter(
  input clk,
  input rst_n,
  input start,
  input [2:0] word_count,
  input [7:0] words [0:7][0:11],
  output reg [2:0] line_breaks,
  output reg is_haiku,
  output reg done
);

  typedef enum {IDLE, PROCESS, CHECK, DONE} state_t;
  state_t state, next_state;
  reg [3:0] cycle_count;
  reg [3:0] syllables [0:7];
  reg [4:0] prefix_sum [0:8];

  // Syllable calculation comb logic
  wire [3:0] syllable_counts [0:7];
  generate for (genvar i = 0; i < 8; i++) begin : syllable_calculation
    reg [11:0] is_vowel, is_alpha;
    reg [3:0] syllable;
    reg in_group, next_in_group;
    always_comb begin
      syllable = 0;
      in_group = 0;
      for (int j = 0; j < 12; j++) begin
        is_alpha[j] = ((words[i][j] >= "A" && words[i][j] <= "Z") || (words[i][j] >= "a" && words[i][j] <= "z"));
        is_vowel[j] = is_alpha[j] && ((words[i][j] & 8'hDF) inside {"A", "E", "I", "O", "U"});
        next_in_group = is_vowel[j] ? 1'b1 : 1'b0;
        if (is_vowel[j] && !in_group) syllable = syllable + 1;
        in_group = next_in_group;
      end
    end
    assign syllable_counts[i] = syllable;
  end endgenerate

  // Prefix sum comb logic
  wire [4:0] prefix_comb [0:8];
  assign prefix_comb[0] = 0;
  generate for (genvar i = 1; i <= 8; i++) begin
    assign prefix_comb[i] = prefix_comb[i-1] + (i <= word_count ? syllable_counts[i-1] : 0);
  end endgenerate

  // Haiku checkingcomb logic
  reg found_valid;
  reg [2:0] w1, w2;
  always_comb begin
    found_valid = 0;
    w1 = 0;
    w2 = 0;
    for (int i = 0; i < word_count; i++) begin
      for (int j = i+1; j < word_count; j++) begin
        if ((prefix_comb[i+1] - prefix_comb[0] == 5) &&
            (prefix_comb[j+1] - prefix_comb[i+1] == 7) &&
            (prefix_comb[word_count] - prefix_comb[j+1] == 5)) begin
          found_valid = 1;
          w1 = i[2:0];
          w2 = j[2:0];
        end
      end
    end
  end

  // FSM and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      done <= 0;
      is_haiku <= 0;
      line_breaks <= 0;
      for (int i = 0; i <8; i++) syllables[i] <= 0;
      for (int i =0; i < 9; i++) prefix_sum[i] <=0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESS;
            cycle_count <= 0;
          end
        end

        PROCESS: begin
          // Register syllable counts and prefix sums
          for (int i=0; i<8; i++) syllables[i] <= syllable_counts[i];
          for (int i=0; i<9; i++) prefix_sum[i] <= prefix_comb[i];
          state <= CHECK;
        end

        CHECK: begin
          is_haiku <= found_valid;
          line_breaks <= {w1, w2} >> 3; // [2:0] output  
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) state <= IDLE;
        end
      endcase

      if (cycle_count >= 14) begin
        state <= DONE;
        is_haiku <= 0;
      end else 
        cycle_count <= cycle_count + 1;
    end
  end
endmodule