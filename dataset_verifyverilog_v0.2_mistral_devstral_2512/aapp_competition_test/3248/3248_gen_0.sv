module untileable_cells (
  input clk,
  input rst_n,
  input start,
  input [5:0] N_valid,
  input [5:0] M_valid,
  input [7:0] street_char_0, street_char_1, street_char_2, street_char_3, street_char_4, street_char_5, street_char_6, street_char_7, street_char_8, street_char_9, street_char_10, street_char_11, street_char_12, street_char_13, street_char_14, street_char_15,
  input [5:0] pattern_len_0, pattern_len_1, pattern_len_2, pattern_len_3, pattern_len_4, pattern_len_5, pattern_len_6, pattern_len_7,
  input [7:0] pattern_0_char_0, pattern_0_char_1, pattern_0_char_2, pattern_0_char_3, pattern_0_char_4, pattern_0_char_5, pattern_0_char_6, pattern_0_char_7, pattern_0_char_8, pattern_0_char_9, pattern_0_char_10, pattern_0_char_11, pattern_0_char_12, pattern_0_char_13, pattern_0_char_14, pattern_0_char_15,
  input [7:0] pattern_1_char_0, pattern_1_char_1, pattern_1_char_2, pattern_1_char_3, pattern_1_char_4, pattern_1_char_5, pattern_1_char_6, pattern_1_char_7, pattern_1_char_8, pattern_1_char_9, pattern_1_char_10, pattern_1_char_11, pattern_1_char_12, pattern_1_char_13, pattern_1_char_14, pattern_1_char_15,
  input [7:0] pattern_2_char_0, pattern_2_char_1, pattern_2_char_2, pattern_2_char_3, pattern_2_char_4, pattern_2_char_5, pattern_2_char_6, pattern_2_char_7, pattern_2_char_8, pattern_2_char_9, pattern_2_char_10, pattern_2_char_11, pattern_2_char_12, pattern_2_char_13, pattern_2_char_14, pattern_2_char_15,
  input [7:0] pattern_3_char_0, pattern_3_char_1, pattern_3_char_2, pattern_3_char_3, pattern_3_char_4, pattern_3_char_5, pattern_3_char_6, pattern_3_char_7, pattern_3_char_8, pattern_3_char_9, pattern_3_char_10, pattern_3_char_11, pattern_3_char_12, pattern_3_char_13, pattern_3_char_14, pattern_3_char_15,
  input [7:0] pattern_4_char_0, pattern_4_char_1, pattern_4_char_2, pattern_4_char_3, pattern_4_char_4, pattern_4_char_5, pattern_4_char_6, pattern_4_char_7, pattern_4_char_8, pattern_4_char_9, pattern_4_char_10, pattern_4_char_11, pattern_4_char_12, pattern_4_char_13, pattern_4_char_14, pattern_4_char_15,
  input [7:0] pattern_5_char_0, pattern_5_char_1, pattern_5_char_2, pattern_5_char_3, pattern_5_char_4, pattern_5_char_5, pattern_5_char_6, pattern_5_char_7, pattern_5_char_8, pattern_5_char_9, pattern_5_char_10, pattern_5_char_11, pattern_5_char_12, pattern_5_char_13, pattern_5_char_14, pattern_5_char_15,
  input [7:0] pattern_6_char_0, pattern_6_char_1, pattern_6_char_2, pattern_6_char_3, pattern_6_char_4, pattern_6_char_5, pattern_6_char_6, pattern_6_char_7, pattern_6_char_8, pattern_6_char_9, pattern_6_char_10, pattern_6_char_11, pattern_6_char_12, pattern_6_char_13, pattern_6_char_14, pattern_6_char_15,
  input [7:0] pattern_7_char_0, pattern_7_char_1, pattern_7_char_2, pattern_7_char_3, pattern_7_char_4, pattern_7_char_5, pattern_7_char_6, pattern_7_char_7, pattern_7_char_8, pattern_7_char_9, pattern_7_char_10, pattern_7_char_11, pattern_7_char_12, pattern_7_char_13, pattern_7_char_14, pattern_7_char_15,
  output reg [5:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_PATTERN,
    CHECK_POSITION,
    MATCH_CHECK,
    COUNT,
    DONE
  } state_t;

  state_t state;
  reg [5:0] pattern_idx;
  reg [5:0] position_idx;
  reg [5:0] char_idx;
  reg [5:0] count_idx;
  reg [15:0] covered;
  reg [5:0] untileable_count;
  reg [5:0] current_pattern_len;
  reg [7:0] current_pattern_char;
  reg [7:0] current_street_char;
  reg match;

  // Pattern and street arrays
  reg [7:0] street [0:15];
  reg [5:0] pattern_len [0:7];
  reg [7:0] pattern [0:7][0:15];

  // Assign inputs to arrays
  always @(*) begin
    street[0] = street_char_0;
    street[1] = street_char_1;
    street[2] = street_char_2;
    street[3] = street_char_3;
    street[4] = street_char_4;
    street[5] = street_char_5;
    street[6] = street_char_6;
    street[7] = street_char_7;
    street[8] = street_char_8;
    street[9] = street_char_9;
    street[10] = street_char_10;
    street[11] = street_char_11;
    street[12] = street_char_12;
    street[13] = street_char_13;
    street[14] = street_char_14;
    street[15] = street_char_15;

    pattern_len[0] = pattern_len_0;
    pattern_len[1] = pattern_len_1;
    pattern_len[2] = pattern_len_2;
    pattern_len[3] = pattern_len_3;
    pattern_len[4] = pattern_len_4;
    pattern_len[5] = pattern_len_5;
    pattern_len[6] = pattern_len_6;
    pattern_len[7] = pattern_len_7;

    pattern[0][0] = pattern_0_char_0;
    pattern[0][1] = pattern_0_char_1;
    pattern[0][2] = pattern_0_char_2;
    pattern[0][3] = pattern_0_char_3;
    pattern[0][4] = pattern_0_char_4;
    pattern[0][5] = pattern_0_char_5;
    pattern[0][6] = pattern_0_char_6;
    pattern[0][7] = pattern_0_char_7;
    pattern[0][8] = pattern_0_char_8;
    pattern[0][9] = pattern_0_char_9;
    pattern[0][10] = pattern_0_char_10;
    pattern[0][11] = pattern_0_char_11;
    pattern[0][12] = pattern_0_char_12;
    pattern[0][13] = pattern_0_char_13;
    pattern[0][14] = pattern_0_char_14;
    pattern[0][15] = pattern_0_char_15;

    pattern[1][0] = pattern_1_char_0;
    pattern[1][1] = pattern_1_char_1;
    pattern[1][2] = pattern_1_char_2;
    pattern[1][3] = pattern_1_char_3;
    pattern[1][4] = pattern_1_char_4;
    pattern[1][5] = pattern_1_char_5;
    pattern[1][6] = pattern_1_char_6;
    pattern[1][7] = pattern_1_char_7;
    pattern[1][8] = pattern_1_char_8;
    pattern[1][9] = pattern_1_char_9;
    pattern[1][10] = pattern_1_char_10;
    pattern[1][11] = pattern_1_char_11;
    pattern[1][12] = pattern_1_char_12;
    pattern[1][13] = pattern_1_char_13;
    pattern[1][14] = pattern_1_char_14;
    pattern[1][15] = pattern_1_char_15;

    pattern[2][0] = pattern_2_char_0;
    pattern[2][1] = pattern_2_char_1;
    pattern[2][2] = pattern_2_char_2;
    pattern[2][3] = pattern_2_char_3;
    pattern[2][4] = pattern_2_char_4;
    pattern[2][5] = pattern_2_char_5;
    pattern[2][6] = pattern_2_char_6;
    pattern[2][7] = pattern_2_char_7;
    pattern[2][8] = pattern_2_char_8;
    pattern[2][9] = pattern_2_char_9;
    pattern[2][10] = pattern_2_char_10;
    pattern[2][11] = pattern_2_char_11;
    pattern[2][12] = pattern_2_char_12;
    pattern[2][13] = pattern_2_char_13;
    pattern[2][14] = pattern_2_char_14;
    pattern[2][15] = pattern_2_char_15;

    pattern[3][0] = pattern_3_char_0;
    pattern[3][1] = pattern_3_char_1;
    pattern[3][2] = pattern_3_char_2;
    pattern[3][3] = pattern_3_char_3;
    pattern[3][4] = pattern_3_char_4;
    pattern[3][5] = pattern_3_char_5;
    pattern[3][6] = pattern_3_char_6;
    pattern[3][7] = pattern_3_char_7;
    pattern[3][8] = pattern_3_char_8;
    pattern[3][9] = pattern_3_char_9;
    pattern[3][10] = pattern_3_char_10;
    pattern[3][11] = pattern_3_char_11;
    pattern[3][12] = pattern_3_char_12;
    pattern[3][13] = pattern_3_char_13;
    pattern[3][14] = pattern_3_char_14;
    pattern[3][15] = pattern_3_char_15;

    pattern[4][0] = pattern_4_char_0;
    pattern[4][1] = pattern_4_char_1;
    pattern[4][2] = pattern_4_char_2;
    pattern[4][3] = pattern_4_char_3;
    pattern[4][4] = pattern_4_char_4;
    pattern[4][5] = pattern_4_char_5;
    pattern[4][6] = pattern_4_char_6;
    pattern[4][7] = pattern_4_char_7;
    pattern[4][8] = pattern_4_char_8;
    pattern[4][9] = pattern_4_char_9;
    pattern[4][10] = pattern_4_char_10;
    pattern[4][11] = pattern_4_char_11;
    pattern[4][12] = pattern_4_char_12;
    pattern[4][13] = pattern_4_char_13;
    pattern[4][14] = pattern_4_char_14;
    pattern[4][15] = pattern_4_char_15;

    pattern[5][0] = pattern_5_char_0;
    pattern[5][1] = pattern_5_char_1;
    pattern[5][2] = pattern_5_char_2;
    pattern[5][3] = pattern_5_char_3;
    pattern[5][4] = pattern_5_char_4;
    pattern[5][5] = pattern_5_char_5;
    pattern[5][6] = pattern_5_char_6;
    pattern[5][7] = pattern_5_char_7;
    pattern[5][8] = pattern_5_char_8;
    pattern[5][9] = pattern_5_char_9;
    pattern[5][10] = pattern_5_char_10;
    pattern[5][11] = pattern_5_char_11;
    pattern[5][12] = pattern_5_char_12;
    pattern[5][13] = pattern_5_char_13;
    pattern[5][14] = pattern_5_char_14;
    pattern[5][15] = pattern_5_char_15;

    pattern[6][0] = pattern_6_char_0;
    pattern[6][1] = pattern_6_char_1;
    pattern[6][2] = pattern_6_char_2;
    pattern[6][3] = pattern_6_char_3;
    pattern[6][4] = pattern_6_char_4;
    pattern[6][5] = pattern_6_char_5;
    pattern[6][6] = pattern_6_char_6;
    pattern[6][7] = pattern_6_char_7;
    pattern[6][8] = pattern_6_char_8;
    pattern[6][9] = pattern_6_char_9;
    pattern[6][10] = pattern_6_char_10;
    pattern[6][11] = pattern_6_char_11;
    pattern[6][12] = pattern_6_char_12;
    pattern[6][13] = pattern_6_char_13;
    pattern[6][14] = pattern_6_char_14;
    pattern[6][15] = pattern_6_char_15;

    pattern[7][0] = pattern_7_char_0;
    pattern[7][1] = pattern_7_char_1;
    pattern[7][2] = pattern_7_char_2;
    pattern[7][3] = pattern_7_char_3;
    pattern[7][4] = pattern_7_char_4;
    pattern[7][5] = pattern_7_char_5;
    pattern[7][6] = pattern_7_char_6;
    pattern[7][7] = pattern_7_char_7;
    pattern[7][8] = pattern_7_char_8;
    pattern[7][9] = pattern_7_char_9;
    pattern[7][10] = pattern_7_char_10;
    pattern[7][11] = pattern_7_char_11;
    pattern[7][12] = pattern_7_char_12;
    pattern[7][13] = pattern_7_char_13;
    pattern[7][14] = pattern_7_char_14;
    pattern[7][15] = pattern_7_char_15;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pattern_idx <= 0;
      position_idx <= 0;
      char_idx <= 0;
      count_idx <= 0;
      covered <= 0;
      untileable_count <= 0;
      current_pattern_len <= 0;
      current_pattern_char <= 0;
      current_street_char <= 0;
      match <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_PATTERN;
            pattern_idx <= 0;
            covered <= 0;
          end
        end

        CHECK_PATTERN: begin
          if (pattern_idx < M_valid) begin
            current_pattern_len <= pattern_len[pattern_idx];
            state <= CHECK_POSITION;
            position_idx <= 0;
          end else begin
            state <= COUNT;
            count_idx <= 0;
            untileable_count <= 0;
          end
        end

        CHECK_POSITION: begin
          if (position_idx <= N_valid - current_pattern_len) begin
            state <= MATCH_CHECK;
            char_idx <= 0;
            match <= 1'b1;
          end else begin
            pattern_idx <= pattern_idx + 1;
            state <= CHECK_PATTERN;
          end
        end

        MATCH_CHECK: begin
          if (char_idx < current_pattern_len) begin
            current_pattern_char <= pattern[pattern_idx][char_idx];
            current_street_char <= street[position_idx + char_idx];
            if (current_pattern_char != current_street_char) begin
              match <= 1'b0;
            end
            char_idx <= char_idx + 1;
          end else begin
            if (match) begin
              // Set covered bits
              for (int i = 0; i < current_pattern_len; i = i + 1) begin
                covered[position_idx + i] = 1'b1;
              end
            end
            position_idx <= position_idx + 1;
            state <= CHECK_POSITION;
          end
        end

        COUNT: begin
          if (count_idx < N_valid) begin
            if (!covered[count_idx]) begin
              untileable_count <= untileable_count + 1;
            end
            count_idx <= count_idx + 1;
          end else begin
            result <= untileable_count;
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule