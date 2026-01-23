module tree_avenue (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_trees,
  input [31:0] road_len,
  input [31:0] road_width,
  input [31:0] tree_pos_0,
  input [31:0] tree_pos_1,
  input [31:0] tree_pos_2,
  input [31:0] tree_pos_3,
  input [31:0] tree_pos_4,
  input [31:0] tree_pos_5,
  input [31:0] tree_pos_6,
  input [31:0] tree_pos_7,
  output reg [63:0] total_distance,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] SORT_INPUTS = 2'b01;
  localparam [1:0] CALCULATE_DP = 2'b10;
  localparam [1:0] OUTPUT_RESULT = 2'b11;

  reg [1:0] state;
  reg [31:0] sorted_trees [0:7];
  reg [31:0] target_pairs_left [0:3];
  reg [31:0] target_pairs_right [0:3];
  reg [63:0] dp [0:8][0:4];
  reg [31:0] sort_counter;
  reg [31:0] dp_counter_i;
  reg [31:0] dp_counter_j;
  reg [31:0] cycle_counter;

  // Bubble sort implementation
  wire [31:0] tree_positions [0:7] = '{tree_pos_0, tree_pos_1, tree_pos_2, tree_pos_3, tree_pos_4, tree_pos_5, tree_pos_6, tree_pos_7};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      total_distance <= 64'b0;
      sort_counter <= 0;
      dp_counter_i <= 0;
      dp_counter_j <= 0;
      cycle_counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SORT_INPUTS;
            done <= 1'b0;
            // Initialize sorted trees
            for (int i = 0; i < 8; i = i + 1) begin
              sorted_trees[i] <= tree_positions[i];
            end
            sort_counter <= 0;
          end
        end

        SORT_INPUTS: begin
          if (sort_counter < 28) begin
            // Bubble sort pass
            for (int i = 0; i < 7; i = i + 1) begin
              if (sorted_trees[i] > sorted_trees[i+1]) begin
                reg [31:0] temp = sorted_trees[i];
                sorted_trees[i] <= sorted_trees[i+1];
                sorted_trees[i+1] <= temp;
              end
            end
            sort_counter <= sort_counter + 1;
          end else begin
            // Calculate target positions
            integer num_pairs = num_trees / 2;
            for (int i = 0; i < num_pairs; i = i + 1) begin
              target_pairs_left[i] <= (i * road_len) / (num_pairs - 1);
              target_pairs_right[i] <= target_pairs_left[i] + road_width;
            end
            state <= CALCULATE_DP;
            dp_counter_i <= 0;
            dp_counter_j <= 0;
            // Initialize DP table
            for (int i = 0; i < 9; i = i + 1) begin
              for (int j = 0; j < 5; j = j + 1) begin
                dp[i][j] <= 64'b0;
              end
            end
          end
        end

        CALCULATE_DP: begin
          if (dp_counter_i < num_trees + 1) begin
            if (dp_counter_j < num_trees/2 + 1) begin
              if (dp_counter_i == 0 || dp_counter_j == 0) begin
                dp[dp_counter_i][dp_counter_j] <= 0;
              end else begin
                reg [63:0] dist_left = calculate_distance(sorted_trees[dp_counter_i-1], target_pairs_left[dp_counter_j-1]);
                reg [63:0] dist_right = calculate_distance(sorted_trees[dp_counter_i-1], target_pairs_right[dp_counter_j-1]);
                reg [63:0] option1 = dp[dp_counter_i-1][dp_counter_j-1] + dist_left;
                reg [63:0] option2 = dp[dp_counter_i-1][dp_counter_j] + dist_right;
                dp[dp_counter_i][dp_counter_j] <= (option1 < option2) ? option1 : option2;
              end
              dp_counter_j <= dp_counter_j + 1;
            end else begin
              dp_counter_j <= 0;
              dp_counter_i <= dp_counter_i + 1;
            end
          end else begin
            state <= OUTPUT_RESULT;
            cycle_counter <= 0;
          end
        end

        OUTPUT_RESULT: begin
          if (cycle_counter < 200) begin
            cycle_counter <= cycle_counter + 1;
          end else begin
            total_distance <= dp[num_trees][num_trees/2];
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

  // Distance calculation function
  function [63:0] calculate_distance;
    input [31:0] tree_pos;
    input [31:0] target_pos;
    reg [63:0] dx;
    reg [63:0] dy;
    reg [63:0] dx_sq;
    reg [63:0] dy_sq;
    reg [63:0] dist_sq;
    reg [31:0] sqrt_result;

    begin
      dx = {32'b0, tree_pos} - {32'b0, target_pos};
      dy = {32'b0, road_width};
      dx_sq = dx * dx;
      dy_sq = dy * dy;
      dist_sq = dx_sq + dy_sq;
      sqrt_result = sqrt_fixed(dist_sq);
      calculate_distance = {32'b0, sqrt_result};
    end
  endfunction

  // Fixed-point square root (Q16.16)
  function [31:0] sqrt_fixed;
    input [63:0] x;
    reg [31:0] guess;
    reg [31:0] next_guess;
    reg [31:0] diff;
    integer i;

    begin
      if (x == 0) begin
        sqrt_fixed = 0;
      end else begin
        guess = x[31:0] >> 1; // Initial guess
        for (i = 0; i < 10; i = i + 1) begin
          next_guess = (guess + (x / guess)) >> 1;
          diff = (next_guess > guess) ? (next_guess - guess) : (guess - next_guess);
          if (diff < 1) begin
            break;
          end
          guess = next_guess;
        end
        sqrt_fixed = guess;
      end
    end
  endfunction

endmodule