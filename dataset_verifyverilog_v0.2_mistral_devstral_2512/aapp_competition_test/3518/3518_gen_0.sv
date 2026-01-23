module min_co2_match (
  input clk,
  input rst_n,
  input start,
  input [2:0] p_idx,
  input [2:0] q_idx,
  input [31:0] weight,
  input weight_valid,
  output reg [31:0] result,
  output reg done,
  output reg impossible
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] LOAD_WEIGHTS = 2'b01;
  localparam [1:0] COMPUTE = 2'b10;
  localparam [1:0] DONE = 2'b11;
  reg [1:0] state = IDLE;

  // Weight matrix (8x8)
  reg [31:0] weight_matrix [0:7][0:7];
  reg [3:0] weight_count = 0;

  // Predefined matchings (28 possible for 8 nodes)
  // Each matching is represented as 4 edges (p,q pairs)
  reg [2:0] matchings [0:27][0:3][0:1]; // [matching][edge][node]

  // Initialize matchings (all possible perfect matchings for 8 nodes)
  initial begin
    // Matching 0: (0,1), (2,3), (4,5), (6,7)
    matchings[0][0][0] = 0; matchings[0][0][1] = 1;
    matchings[0][1][0] = 2; matchings[0][1][1] = 3;
    matchings[0][2][0] = 4; matchings[0][2][1] = 5;
    matchings[0][3][0] = 6; matchings[0][3][1] = 7;

    // Matching 1: (0,1), (2,4), (3,5), (6,7)
    matchings[1][0][0] = 0; matchings[1][0][1] = 1;
    matchings[1][1][0] = 2; matchings[1][1][1] = 4;
    matchings[1][2][0] = 3; matchings[1][2][1] = 5;
    matchings[1][3][0] = 6; matchings[1][3][1] = 7;

    // Matching 2: (0,1), (2,5), (3,4), (6,7)
    matchings[2][0][0] = 0; matchings[2][0][1] = 1;
    matchings[2][1][0] = 2; matchings[2][1][1] = 5;
    matchings[2][2][0] = 3; matchings[2][2][1] = 4;
    matchings[2][3][0] = 6; matchings[2][3][1] = 7;

    // Matching 3: (0,1), (2,6), (3,7), (4,5)
    matchings[3][0][0] = 0; matchings[3][0][1] = 1;
    matchings[3][1][0] = 2; matchings[3][1][1] = 6;
    matchings[3][2][0] = 3; matchings[3][2][1] = 7;
    matchings[3][3][0] = 4; matchings[3][3][1] = 5;

    // Matching 4: (0,1), (2,7), (3,6), (4,5)
    matchings[4][0][0] = 0; matchings[4][0][1] = 1;
    matchings[4][1][0] = 2; matchings[4][1][1] = 7;
    matchings[4][2][0] = 3; matchings[4][2][1] = 6;
    matchings[4][3][0] = 4; matchings[4][3][1] = 5;

    // Matching 5: (0,2), (1,3), (4,5), (6,7)
    matchings[5][0][0] = 0; matchings[5][0][1] = 2;
    matchings[5][1][0] = 1; matchings[5][1][1] = 3;
    matchings[5][2][0] = 4; matchings[5][2][1] = 5;
    matchings[5][3][0] = 6; matchings[5][3][1] = 7;

    // Matching 6: (0,2), (1,4), (3,5), (6,7)
    matchings[6][0][0] = 0; matchings[6][0][1] = 2;
    matchings[6][1][0] = 1; matchings[6][1][1] = 4;
    matchings[6][2][0] = 3; matchings[6][2][1] = 5;
    matchings[6][3][0] = 6; matchings[6][3][1] = 7;

    // Matching 7: (0,2), (1,5), (3,4), (6,7)
    matchings[7][0][0] = 0; matchings[7][0][1] = 2;
    matchings[7][1][0] = 1; matchings[7][1][1] = 5;
    matchings[7][2][0] = 3; matchings[7][2][1] = 4;
    matchings[7][3][0] = 6; matchings[7][3][1] = 7;

    // Matching 8: (0,2), (1,6), (3,7), (4,5)
    matchings[8][0][0] = 0; matchings[8][0][1] = 2;
    matchings[8][1][0] = 1; matchings[8][1][1] = 6;
    matchings[8][2][0] = 3; matchings[8][2][1] = 7;
    matchings[8][3][0] = 4; matchings[8][3][1] = 5;

    // Matching 9: (0,2), (1,7), (3,6), (4,5)
    matchings[9][0][0] = 0; matchings[9][0][1] = 2;
    matchings[9][1][0] = 1; matchings[9][1][1] = 7;
    matchings[9][2][0] = 3; matchings[9][2][1] = 6;
    matchings[9][3][0] = 4; matchings[9][3][1] = 5;

    // Matching 10: (0,3), (1,2), (4,5), (6,7)
    matchings[10][0][0] = 0; matchings[10][0][1] = 3;
    matchings[10][1][0] = 1; matchings[10][1][1] = 2;
    matchings[10][2][0] = 4; matchings[10][2][1] = 5;
    matchings[10][3][0] = 6; matchings[10][3][1] = 7;

    // Matching 11: (0,3), (1,4), (2,5), (6,7)
    matchings[11][0][0] = 0; matchings[11][0][1] = 3;
    matchings[11][1][0] = 1; matchings[11][1][1] = 4;
    matchings[11][2][0] = 2; matchings[11][2][1] = 5;
    matchings[11][3][0] = 6; matchings[11][3][1] = 7;

    // Matching 12: (0,3), (1,5), (2,4), (6,7)
    matchings[12][0][0] = 0; matchings[12][0][1] = 3;
    matchings[12][1][0] = 1; matchings[12][1][1] = 5;
    matchings[12][2][0] = 2; matchings[12][2][1] = 4;
    matchings[12][3][0] = 6; matchings[12][3][1] = 7;

    // Matching 13: (0,3), (1,6), (2,7), (4,5)
    matchings[13][0][0] = 0; matchings[13][0][1] = 3;
    matchings[13][1][0] = 1; matchings[13][1][1] = 6;
    matchings[13][2][0] = 2; matchings[13][2][1] = 7;
    matchings[13][3][0] = 4; matchings[13][3][1] = 5;

    // Matching 14: (0,3), (1,7), (2,6), (4,5)
    matchings[14][0][0] = 0; matchings[14][0][1] = 3;
    matchings[14][1][0] = 1; matchings[14][1][1] = 7;
    matchings[14][2][0] = 2; matchings[14][2][1] = 6;
    matchings[14][3][0] = 4; matchings[14][3][1] = 5;

    // Matching 15: (0,4), (1,2), (3,5), (6,7)
    matchings[15][0][0] = 0; matchings[15][0][1] = 4;
    matchings[15][1][0] = 1; matchings[15][1][1] = 2;
    matchings[15][2][0] = 3; matchings[15][2][1] = 5;
    matchings[15][3][0] = 6; matchings[15][3][1] = 7;

    // Matching 16: (0,4), (1,3), (2,5), (6,7)
    matchings[16][0][0] = 0; matchings[16][0][1] = 4;
    matchings[16][1][0] = 1; matchings[16][1][1] = 3;
    matchings[16][2][0] = 2; matchings[16][2][1] = 5;
    matchings[16][3][0] = 6; matchings[16][3][1] = 7;

    // Matching 17: (0,4), (1,5), (2,3), (6,7)
    matchings[17][0][0] = 0; matchings[17][0][1] = 4;
    matchings[17][1][0] = 1; matchings[17][1][1] = 5;
    matchings[17][2][0] = 2; matchings[17][2][1] = 3;
    matchings[17][3][0] = 6; matchings[17][3][1] = 7;

    // Matching 18: (0,4), (1,6), (2,7), (3,5)
    matchings[18][0][0] = 0; matchings[18][0][1] = 4;
    matchings[18][1][0] = 1; matchings[18][1][1] = 6;
    matchings[18][2][0] = 2; matchings[18][2][1] = 7;
    matchings[18][3][0] = 3; matchings[18][3][1] = 5;

    // Matching 19: (0,4), (1,7), (2,6), (3,5)
    matchings[19][0][0] = 0; matchings[19][0][1] = 4;
    matchings[19][1][0] = 1; matchings[19][1][1] = 7;
    matchings[19][2][0] = 2; matchings[19][2][1] = 6;
    matchings[19][3][0] = 3; matchings[19][3][1] = 5;

    // Matching 20: (0,5), (1,2), (3,4), (6,7)
    matchings[20][0][0] = 0; matchings[20][0][1] = 5;
    matchings[20][1][0] = 1; matchings[20][1][1] = 2;
    matchings[20][2][0] = 3; matchings[20][2][1] = 4;
    matchings[20][3][0] = 6; matchings[20][3][1] = 7;

    // Matching 21: (0,5), (1,3), (2,4), (6,7)
    matchings[21][0][0] = 0; matchings[21][0][1] = 5;
    matchings[21][1][0] = 1; matchings[21][1][1] = 3;
    matchings[21][2][0] = 2; matchings[21][2][1] = 4;
    matchings[21][3][0] = 6; matchings[21][3][1] = 7;

    // Matching 22: (0,5), (1,4), (2,3), (6,7)
    matchings[22][0][0] = 0; matchings[22][0][1] = 5;
    matchings[22][1][0] = 1; matchings[22][1][1] = 4;
    matchings[22][2][0] = 2; matchings[22][2][1] = 3;
    matchings[22][3][0] = 6; matchings[22][3][1] = 7;

    // Matching 23: (0,5), (1,6), (2,7), (3,4)
    matchings[23][0][0] = 0; matchings[23][0][1] = 5;
    matchings[23][1][0] = 1; matchings[23][1][1] = 6;
    matchings[23][2][0] = 2; matchings[23][2][1] = 7;
    matchings[23][3][0] = 3; matchings[23][3][1] = 4;

    // Matching 24: (0,5), (1,7), (2,6), (3,4)
    matchings[24][0][0] = 0; matchings[24][0][1] = 5;
    matchings[24][1][0] = 1; matchings[24][1][1] = 7;
    matchings[24][2][0] = 2; matchings[24][2][1] = 6;
    matchings[24][3][0] = 3; matchings[24][3][1] = 4;

    // Matching 25: (0,6), (1,2), (3,7), (4,5)
    matchings[25][0][0] = 0; matchings[25][0][1] = 6;
    matchings[25][1][0] = 1; matchings[25][1][1] = 2;
    matchings[25][2][0] = 3; matchings[25][2][1] = 7;
    matchings[25][3][0] = 4; matchings[25][3][1] = 5;

    // Matching 26: (0,6), (1,3), (2,7), (4,5)
    matchings[26][0][0] = 0; matchings[26][0][1] = 6;
    matchings[26][1][0] = 1; matchings[26][1][1] = 3;
    matchings[26][2][0] = 2; matchings[26][2][1] = 7;
    matchings[26][3][0] = 4; matchings[26][3][1] = 5;

    // Matching 27: (0,6), (1,4), (2,7), (3,5)
    matchings[27][0][0] = 0; matchings[27][0][1] = 6;
    matchings[27][1][0] = 1; matchings[27][1][1] = 4;
    matchings[27][2][0] = 2; matchings[27][2][1] = 7;
    matchings[27][3][0] = 3; matchings[27][3][1] = 5;
  end

  // Compute minimum matching
  reg [31:0] matching_sums [0:27];
  reg [31:0] min_sum;
  reg [4:0] min_idx;
  reg [31:0] current_sum;
  reg [4:0] i;
  reg [1:0] j;
  reg [2:0] p, q;
  reg valid_matching;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      weight_count <= 0;
      done <= 0;
      impossible <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_WEIGHTS;
            weight_count <= 0;
          end
        end

        LOAD_WEIGHTS: begin
          if (weight_valid) begin
            weight_matrix[p_idx][q_idx] <= weight;
            weight_matrix[q_idx][p_idx] <= weight; // Symmetric
            weight_count <= weight_count + 1;
          end
          if (!start && weight_count == 28) begin // All weights loaded
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          // Compute all matching sums
          for (i = 0; i < 28; i = i + 1) begin
            current_sum = 0;
            valid_matching = 1;
            for (j = 0; j < 4; j = j + 1) begin
              p = matchings[i][j][0];
              q = matchings[i][j][1];
              if (weight_matrix[p][q] == 0) begin
                valid_matching = 0;
              end
              current_sum = current_sum + weight_matrix[p][q];
            end
            if (valid_matching) begin
              matching_sums[i] = current_sum;
            end else begin
              matching_sums[i] = 32'hFFFFFFFF; // Invalid
            end
          end

          // Find minimum valid matching
          min_sum = 32'hFFFFFFFF;
          min_idx = 0;
          for (i = 0; i < 28; i = i + 1) begin
            if (matching_sums[i] < min_sum) begin
              min_sum = matching_sums[i];
              min_idx = i;
            end
          end

          if (min_sum == 32'hFFFFFFFF) begin
            impossible <= 1;
            result <= 0;
          end else begin
            impossible <= 0;
            result <= min_sum;
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (start) begin
            state <= IDLE;
            done <= 0;
            impossible <= 0;
          end
        end
      endcase
    end
  end

endmodule