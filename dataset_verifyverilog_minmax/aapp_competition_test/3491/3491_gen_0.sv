module staircase_solver(
  input clk,
  input rst_n,
  input start,
  input [1:0] N, // Fixed to 4 floors (ignore input)
  input [2:0] M, // Number of staircases (0-6)
  input [5:0][3:0] current_edges,
  input [5:0][3:0] desired_edges,
  output reg [3:0] sequence_type,
  output reg [15:0][1:0] sequence_floor,
  output reg [4:0] solution_length,
  output reg done,
  output reg valid
);

  // State machine states
  typedef enum {
    IDLE = 3'b000,
    INIT = 3'b001,
    CHECK_MATCH = 3'b010,
    PRESS_RED = 3'b011,
    PRESS_GREEN = 3'b100,
    UPDATE_STATE = 3'b101,
    DONE = 3'b110
  } state_t;
  
  state_t current_state, next_state;
  
  // BFS variables
  reg [5:0] queue [0:63];
  reg [5:0] head, tail;
  reg [63:0] visited;
  reg [5:0] parent_state [0:63];
  reg [2:0] action_taken [0:63];
  
  // Current BFS state being expanded
  reg [5:0] current_expand_state;
  reg [3:0] action_index; // 0-7 for 8 actions
  
  // Target state
  reg [5:0] target_state;
  
  // Sequence building variables
  reg [4:0] seq_count;
  reg [2:0] seq_mem [0:15];
  reg [5:0] backtrack_state;
  reg found_flag;
  
  // State conversion functions
  function [5:0] convert_edges_to_state;
    input [5:0][3:0] edges;
    input [2:0] M;
    reg [5:0] state;
    reg [1:0] a, b;
    begin
      state = 6'b0;
      for (int i = 0; i < 6; i++) begin
        if (i < M) begin
          a = edges[i][3:2];
          b = edges[i][1:0];
          // Sort to ensure a is the max endpoint
          if (a < b) begin
            {a, b} = {b, a};
          end
          // Set corresponding bit in state
          case ({a, b})
            4'b1000: state[0] = 1; // (0,1)
            4'b1010: state[1] = 1; // (0,2)
            4'b1100: state[2] = 1; // (0,3)
            4'b1011: state[3] = 1; // (1,2)
            4'b1101: state[4] = 1; // (1,3)
            4'b1110: state[5] = 1; // (2,3)
          endcase
        end
      end
      convert_edges_to_state = state;
    end
  endfunction
  
  function [5:0] update_state_red;
    input [5:0] state;
    input [1:0] floor;
    reg [5:0] new_state;
    reg [1:0] i, j, new_j;
    begin
      new_state = state;
      // Process each edge in the 6 possible edges
      for (int k = 0; k < 6; k++) begin
        if (state[k] == 1) begin
          // Get endpoints of this edge
          case (k)
            0: {i, j} = {2'b00, 2'b01}; // (0,1)
            1: {i, j} = {2'b00, 2'b10}; // (0,2)
            2: {i, j} = {2'b00, 2'b11}; // (0,3)
            3: {i, j} = {2'b01, 2'b10}; // (1,2)
            4: {i, j} = {2'b01, 2'b11}; // (1,3)
            5: {i, j} = {2'b10, 2'b11}; // (2,3)
          endcase
          
          // If this edge is incident to the floor being pressed
          if (i == floor) begin
            new_j = (j + 1) % 4;
            if (new_j == floor) begin
              new_j = (j + 2) % 4;
            end
            // Remove old edge and add new edge
            new_state[k] = 0;
            // Find new edge in the 6 possible edges
            if (i < new_j) begin
              case ({i, new_j})
                4'b0001: new_state[0] = 1;
                4'b0010: new_state[1] = 1;
                4'b0011: new_state[2] = 1;
                4'b0110: new_state[3] = 1;
                4'b0111: new_state[4] = 1;
                4'b1011: new_state[5] = 1;
              endcase
            end else begin
              case ({new_j, i})
                4'b0001: new_state[0] = 1;
                4'b0010: new_state[1] = 1;
                4'b0011: new_state[2] = 1;
                4'b0110: new_state[3] = 1;
                4'b0111: new_state[4] = 1;
                4'b1011: new_state[5] = 1;
              endcase
            end
          end else if (j == floor) begin
            new_j = (i + 1) % 4;
            if (new_j == floor) begin
              new_j = (i + 2) % 4;
            end
            new_state[k] = 0;
            if (new_j < floor) begin
              case ({new_j, floor})
                4'b0001: new_state[0] = 1;
                4'b0010: new_state[1] = 1;
                4'b0011: new_state[2] = 1;
                4'b0110: new_state[3] = 1;
                4'b0111: new_state[4] = 1;
                4'b1011: new_state[5] = 1;
              endcase
            end else begin
              case ({floor, new_j})
                4'b0001: new_state[0] = 1;
                4'b0010: new_state[1] = 1;
                4'b0011: new_state[2] = 1;
                4'b0110: new_state[3] = 1;
                4'b0111: new_state[4] = 1;
                4'b1011: new_state[5] = 1;
              endcase
            end
          end
        end
      end
      update_state_red = new_state;
    end
  endfunction
  
  function [5:0] update_state_green;
    input [5:0] state;
    input [1:0] floor;
    begin
      update_state_green = update_state_red(update_state_red(state, floor), floor);
    end
  endfunction
  
  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end
  
  // State machine combinational logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end else begin
          next_state = IDLE;
        end
      end
      
      INIT: begin
        // Convert current and desired edges to state representation
        current_expand_state = convert_edges_to_state(current_edges, M);
        target_state = convert_edges_to_state(desired_edges, M);
        
        // Initialize BFS
        head = 0;
        tail = 0;
        queue[0] = current_expand_state;
        visited = 0;
        visited[current_expand_state] = 1;
        parent_state[current_expand_state] = current_expand_state;
        action_taken[current_expand_state] = 0;
        action_index = 0;
        found_flag = 0;
        
        next_state = CHECK_MATCH;
      end
      
      CHECK_MATCH: begin
        if (current_expand_state == target_state) begin
          found_flag = 1;
          next_state = DONE;
        end else if (head > tail) begin
          // Queue is empty, no solution found
          next_state = DONE;
        end else if (action_index == 8) begin
          // Finished all actions for current state, move to next
          head = head + 1;
          if (head == 64) head = 0;
          current_expand_state = queue[head];
          action_index = 0;
          next_state = CHECK_MATCH;
        end else begin
          // Check if current action is red or green
          if (action_index[0] == 0) begin // Even index: red
            next_state = PRESS_RED;
          end else begin // Odd index: green
            next_state = PRESS_GREEN;
          end
        end
      end
      
      PRESS_RED: begin
        reg [1:0] floor;
        reg [5:0] new_state;
        floor = action_index[3:1]; // Get floor from action_index
        new_state = update_state_red(current_expand_state, floor);
        
        if (!visited[new_state]) begin
          visited[new_state] = 1;
          parent_state[new_state] = current_expand_state;
          action_taken[new_state] = {floor, 2'b00}; // red button
          
          tail = tail + 1;
          if (tail == 64) tail = 0;
          queue[tail] = new_state;
        end
        
        next_state = UPDATE_STATE;
      end
      
      PRESS_GREEN: begin
        reg [1:0] floor;
        reg [5:0] new_state;
        floor = (action_index - 1) >> 1;
        new_state = update_state_green(current_expand_state, floor);
        
        if (!visited[new_state]) begin
          visited[new_state] = 1;
          parent_state[new_state] = current_expand_state;
          action_taken[new_state] = {floor, 2'b01}; // green button
          
          tail = tail + 1;
          if (tail == 64) tail = 0;
          queue[tail] = new_state;
        end
        
        next_state = UPDATE_STATE;
      end
      
      UPDATE_STATE: begin
        action_index = action_index + 1;
        next_state = CHECK_MATCH;
      end
      
      DONE: begin
        if (found_flag) begin
          // Build solution sequence
          if (seq_count == 0) begin
            backtrack_state = target_state;
          end
          
          if (seq_count < 16 && backtrack_state != current_expand_state) begin
            seq_mem[seq_count] = action_taken[backtrack_state];
            backtrack_state = parent_state[backtrack_state];
            seq_count = seq_count + 1;
            next_state = DONE;
          end else begin
            // Output the sequence
            for (int i = 0; i < 16; i++) begin
              if (i < seq_count) begin
                sequence_floor[i] = seq_mem[seq_count-1-i][1:0];
                sequence_type[i] = seq_mem[seq_count-1-i][2];
              end else begin
                sequence_floor[i] = 0;
                sequence_type[i] = 0;
              end
            end
            solution_length = seq_count;
            done = 1;
            valid = 1;
            next_state = IDLE;
          end
        end else begin
          // No solution found
          done = 1;
          valid = 0;
          solution_length = 0;
          next_state = IDLE;
        end
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  // Reset variables when leaving DONE state
  always @(posedge clk) begin
    if (current_state == DONE && next_state == IDLE) begin
      seq_count <= 0;
    end
  end
  
endmodule