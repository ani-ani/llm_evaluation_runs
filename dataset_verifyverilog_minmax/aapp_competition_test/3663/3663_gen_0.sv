module army_move_calculator(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [3:0] num_nations, // 0-8 nations (0=none, 1-8 valid)
  input [3:0] parent_node [0:7], // parent for each node (4-bit per node)
  input [15:0] move_costs [0:7], // cost to parent (16-bit per node)
  input [15:0] init_armies [0:7], // x_i initial armies
  input [15:0] req_armies [0:7], // y_i required armies
  output reg [31:0] total_cost, // accumulated cost (32-bit)
  output reg done // high when calculation complete
);

  // State machine states
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    PROCESS_BFS = 2'b01,
    CALCULATE   = 2'b10,
    DONE        = 2'b11
  } state_t;

  state_t current_state, next_state;
  reg [3:0] cycle_count; // 4-bit counter for 16 cycles
  reg [15:0] army [0:7]; // Local copy of army counts
  reg [3:0] current_index; // Current node being processed
  integer i; // Loop variable

  // State machine sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cycle_count <= 4'b0;
      total_cost <= 32'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      cycle_count <= cycle_count + 1'b1;
      
      case (current_state)
        CALCULATE: begin
          // Update army array for current node
          if (cycle_count >= 4'd9 && cycle_count <= 4'd16) begin
            current_index = cycle_count - 4'd9;
            if (current_index < num_nations) begin
              // Calculate movement and cost
              int16_t movement;
              movement = army[current_index] - req_armies[current_index];
              total_cost <= total_cost + (move_costs[current_index] * (movement >= 0 ? movement : -movement));
              
              // Update parent node's army count if not root
              if (parent_node[current_index] != current_index && parent_node[current_index] < num_nations) begin
                army[parent_node[current_index]] <= army[parent_node[current_index]] + movement;
              end
            end
          end
        end
        
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESS_BFS;
          cycle_count = 4'b0; // Reset cycle count for BFS
        end
      end
      
      PROCESS_BFS: begin
        if (cycle_count == 4'd7) begin // 8 cycles total (0-7)
          next_state = CALCULATE;
          cycle_count = 4'd8; // Start calculate at cycle 9 (count 8)
        end
      end
      
      CALCULATE: begin
        if (cycle_count == 4'd15) begin // 8 cycles total (8-15)
          next_state = DONE;
        end
      end
      
      DONE: begin
        // Stay in DONE until reset
      end
    endcase
  end

  // Initialize army array when entering CALCULATE state
  always_ff @(posedge clk) begin
    if (current_state == PROCESS_BFS && next_state == CALCULATE) begin
      for (i = 0; i < 8; i++) begin
        army[i] <= init_armies[i];
      end
      total_cost <= 32'b0;
    end
  end

endmodule