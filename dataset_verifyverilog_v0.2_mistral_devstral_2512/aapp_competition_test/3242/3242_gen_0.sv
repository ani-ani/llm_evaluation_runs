module find_min_energy (
  input clk,
  input rst_n,
  input start,
  input [7:0] num_boxes,
  input [15:0] target_prob,
  input [9:0] energy_in,
  input [15:0] prob_in,
  input load_valid,
  output reg load_ready,
  output reg [9:0] min_energy,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] box_count;
  reg [9:0] dp [0:2048];
  reg [15:0] prob_idx;
  reg [9:0] current_energy;
  reg [15:0] current_prob;
  reg [9:0] temp_dp [0:2048];
  reg [15:0] scan_idx;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      box_count <= 0;
      load_ready <= 1'b0;
      valid <= 1'b0;
      min_energy <= 10'h3FF;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end else if (load_valid) begin
          next_state = LOAD;
        end
      end
      LOAD: begin
        if (box_count == num_boxes - 1 && load_valid) begin
          next_state = IDLE;
        end
      end
      PROCESSING: begin
        if (scan_idx == 2048) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Load phase logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      box_count <= 0;
      load_ready <= 1'b0;
    end else begin
      case (current_state)
        LOAD: begin
          if (load_valid) begin
            if (box_count < num_boxes) begin
              dp[box_count] = energy_in;
              current_prob = prob_in;
              box_count <= box_count + 1;
              load_ready <= 1'b1;
            end else begin
              load_ready <= 1'b0;
            end
          end else begin
            load_ready <= 1'b1;
          end
        end
        default: begin
          load_ready <= 1'b0;
        end
      endcase
    end
  end

  // Processing phase logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prob_idx <= 0;
      current_energy <= 0;
      scan_idx <= 0;
      for (int i = 0; i < 2049; i++) begin
        dp[i] = 10'h3FF;
      end
      dp[0] = 0;
    end else begin
      case (current_state)
        PROCESSING: begin
          if (prob_idx == 0) begin
            // Initialize temp_dp
            for (int i = 0; i < 2049; i++) begin
              temp_dp[i] = dp[i];
            end
          end
          if (prob_idx < 2048) begin
            if (dp[prob_idx] != 10'h3FF) begin
              current_energy = dp[prob_idx] + energy_in;
              current_prob = prob_idx + prob_in;
              if (current_prob < 2049 && current_energy < temp_dp[current_prob]) begin
                temp_dp[current_prob] = current_energy;
              end
            end
            prob_idx <= prob_idx + 1;
          end else begin
            // Copy temp_dp back to dp
            for (int i = 0; i < 2049; i++) begin
              dp[i] = temp_dp[i];
            end
            prob_idx <= 0;
            scan_idx <= target_prob;
          end
        end
        DONE: begin
          if (scan_idx < 2049) begin
            if (dp[scan_idx] != 10'h3FF) begin
              min_energy <= dp[scan_idx];
              valid <= 1'b1;
            end
            scan_idx <= scan_idx + 1;
          end
        end
      endcase
    end
  end

endmodule