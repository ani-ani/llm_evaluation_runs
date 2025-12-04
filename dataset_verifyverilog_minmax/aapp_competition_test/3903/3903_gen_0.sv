module three_states_router(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] grid [0:7][0:7], // Grid cells [2:0]: {state[1:0], is_road_allowed}
  output reg [7:0] result, // Min roads needed (255 = -1 if impossible)
  output reg done // High when computation complete
);

  // Constants
  parameter WIDTH = 8;
  parameter HEIGHT = 8;
  parameter STATE_SETS = 8;
  parameter MAX_COST = 255;

  // BFS state storage
  reg [7:0] min_cost [WIDTH-1:0][HEIGHT-1:0][STATE_SETS-1:0];
  wire [7:0] next_min_cost [WIDTH-1:0][HEIGHT-1:0][STATE_SETS-1:0];

  // State machine
  reg [1:0] state;
  reg [5:0] iter_count;

  // BFS direction vectors
  reg [1:0] directions [3:0];
  assign directions[0] = 2'b00; // -1, 0
  assign directions[1] = 2'b01; // 1, 0
  assign directions[2] = 2'b10; // 0, -1
  assign directions[3] = 2'b11; // 0, 1

  // BFS next state combinational logic
  always_comb begin
    next_min_cost = min_cost; // Default: no change
    
    for (int i = 0; i < WIDTH; i++) begin
      for (int j = 0; j < HEIGHT; j++) begin
        for (int s = 0; s < STATE_SETS; s++) begin
          if (min_cost[i][j][s] < MAX_COST) begin
            int current_cost = min_cost[i][j][s];
            
            // Check all 4 neighbors
            for (int k = 0; k < 4; k++) begin
              int ni = i;
              int nj = j;
              
              case (directions[k])
                2'b00: ni = i - 1; // up
                2'b01: ni = i + 1; // down
                2'b10: nj = j - 1; // left
                2'b11: nj = j + 1; // right
              endcase
              
              // Check bounds
              if (ni >= 0 && ni < WIDTH && nj >= 0 && nj < HEIGHT) begin
                // Check if cell is road-allowed
                if (grid[ni][nj][2] == 1'b1) begin
                  int new_s = s;
                  int new_cost = current_cost;
                  
                  // If neighbor is a state cell, add its state
                  if (grid[ni][nj][1:0] < 3) begin
                    new_s = s | (1 << grid[ni][nj][1:0]);
                    // No additional cost for state cells
                  end
                  else begin
                    // Free cell: add road cost
                    new_cost = current_cost + 1;
                  end
                  
                  // Update if better cost found
                  if (new_cost < min_cost[ni][nj][new_s]) begin
                    next_min_cost[ni][nj][new_s] = new_cost;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= 2'b00;
      iter_count <= 6'd0;
      result <= 8'd255;
      done <= 1'b0;
      
      // Initialize min_cost to MAX_COST
      for (int i = 0; i < WIDTH; i++) begin
        for (int j = 0; j < HEIGHT; j++) begin
          for (int s = 0; s < STATE_SETS; s++) begin
            min_cost[i][j][s] <= MAX_COST;
          end
        end
      end
    end
    else begin
      case (state)
        2'b00: begin // IDLE
          if (start) begin
            state <= 2'b01;
          end
        end
        
        2'b01: begin // INIT
          // Initialize min_cost to MAX_COST
          for (int i = 0; i < WIDTH; i++) begin
            for (int j = 0; j < HEIGHT; j++) begin
              for (int s = 0; s < STATE_SETS; s++) begin
                min_cost[i][j][s] <= MAX_COST;
              end
            end
          end
          
          // Initialize state cells
          for (int i = 0; i < WIDTH; i++) begin
            for (int j = 0; j < HEIGHT; j++) begin
              if (grid[i][j][2] == 1'b1) begin // road allowed
                if (grid[i][j][1:0] < 3) begin // valid state (0,1,2)
                  int state_bit = grid[i][j][1:0];
                  min_cost[i][j][1 << state_bit] <= 8'd0;
                end
              end
            end
          end
          
          state <= 2'b10;
          iter_count <= 6'd0;
        end
        
        2'b10: begin // ITER
          if (iter_count < 6'd64) begin
            // Update min_cost from next_min_cost
            for (int i = 0; i < WIDTH; i++) begin
              for (int j = 0; j < HEIGHT; j++) begin
                for (int s = 0; s < STATE_SETS; s++) begin
                  min_cost[i][j][s] <= next_min_cost[i][j][s];
                end
              end
            end
            iter_count <= iter_count + 1;
          end
          else begin
            state <= 2'b11;
          end
        end
        
        2'b11: begin // DONE
          // Find minimum cost for full state set (7 = 111b)
          int min_cost_7 = MAX_COST;
          for (int i = 0; i < WIDTH; i++) begin
            for (int j = 0; j < HEIGHT; j++) begin
              if (min_cost[i][j][7] < min_cost_7) begin
                min_cost_7 = min_cost[i][j][7];
              end
            end
          end
          
          if (min_cost_7 == MAX_COST) begin
            result <= 8'd255; // Impossible
          end
          else begin
            result <= min_cost_7;
          end
          
          done <= 1'b1;
          state <= 2'b00; // Return to IDLE
        end
        
        default: state <= 2'b00;
      endcase
    end
  end

endmodule