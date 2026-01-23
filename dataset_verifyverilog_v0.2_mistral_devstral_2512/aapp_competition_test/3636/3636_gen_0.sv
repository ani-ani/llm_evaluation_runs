module min_obstacles_counter (
  input clk,
  input rst,
  input [15:0] grid_config,
  output reg [3:0] min_obstacles,
  output reg [7:0] count_ways,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    COUNT,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [15:0] config_counter;
  reg [3:0] obstacle_count;
  reg [3:0] min_obs_found;
  reg [7:0] ways_count;
  reg [8:0] subgrid_check;
  reg [8:0] all_covered;
  reg start;

  // State register
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      current_state <= IDLE;
      config_counter <= 0;
      obstacle_count <= 0;
      min_obs_found <= 4'b1111;
      ways_count <= 0;
      subgrid_check <= 0;
      all_covered <= 0;
      valid <= 0;
      min_obstacles <= 0;
      count_ways <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK;
      end
      CHECK: begin
        next_state = COUNT;
      end
      COUNT: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk) begin
    if (rst) begin
      // Reset handled in state register
    end else begin
      case (current_state)
        IDLE: begin
          // Wait for start
        end
        CHECK: begin
          // Check all 9 subgrids
          subgrid_check[0] = grid_config[0] || grid_config[1] || grid_config[4] || grid_config[5];
          subgrid_check[1] = grid_config[1] || grid_config[2] || grid_config[5] || grid_config[6];
          subgrid_check[2] = grid_config[2] || grid_config[3] || grid_config[6] || grid_config[7];
          subgrid_check[3] = grid_config[4] || grid_config[5] || grid_config[8] || grid_config[9];
          subgrid_check[4] = grid_config[5] || grid_config[6] || grid_config[9] || grid_config[10];
          subgrid_check[5] = grid_config[6] || grid_config[7] || grid_config[10] || grid_config[11];
          subgrid_check[6] = grid_config[8] || grid_config[9] || grid_config[12] || grid_config[13];
          subgrid_check[7] = grid_config[9] || grid_config[10] || grid_config[13] || grid_config[14];
          subgrid_check[8] = grid_config[10] || grid_config[11] || grid_config[14] || grid_config[15];
          all_covered = &subgrid_check;
        end
        COUNT: begin
          // Count obstacles
          obstacle_count = ^grid_config ? 1 : 0;
          obstacle_count = obstacle_count + (grid_config[1] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[2] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[3] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[4] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[5] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[6] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[7] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[8] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[9] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[10] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[11] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[12] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[13] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[14] ? 1 : 0);
          obstacle_count = obstacle_count + (grid_config[15] ? 1 : 0);
          
          // Update min and count
          if (all_covered) begin
            if (obstacle_count < min_obs_found) begin
              min_obs_found = obstacle_count;
              ways_count = 1;
            end else if (obstacle_count == min_obs_found) begin
              ways_count = ways_count + 1;
            end
          end
        end
        DONE: begin
          min_obstacles = min_obs_found;
          count_ways = ways_count;
          valid = 1;
        end
      endcase
    end
  end

  // Start signal (assumed to be connected externally)
  assign start = 1'b0; // Replace with actual start signal

endmodule