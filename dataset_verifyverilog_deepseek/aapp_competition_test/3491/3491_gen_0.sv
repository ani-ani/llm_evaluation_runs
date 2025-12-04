module staircase_solver (
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [5:0][3:0] current_edges,
  input [5:0][3:0] desired_edges,
  output reg [3:0] sequence_type,
  output reg [15:0][1:0] sequence_floor,
  output reg [4:0] solution_length,
  output reg done,
  output reg valid
);

// State machine definitions
localparam IDLE = 0;
localparam INIT = 1;
localparam CHECK_MATCH = 2;
localparam PRESS_RED = 3;
localparam PRESS_GREEN = 4;
localparam UPDATE_STATE = 5;
localparam DONE = 6;

reg [2:0] state, next_state;

// Working edge storage
reg [5:0][3:0] working_edges;

// Sequence storage
reg [3:0] seq_type [0:15];
reg [1:0] seq_floor [0:15];
reg [4:0] step_counter;
reg [1:0] floor_index;
reg press_type; // 0: RED, 1: GREEN

// Edge comparison logic
function logic compare_edges;
  input [5:0][3:0] edgesA;
  input [5:0][3:0] edgesB;
  input [2:0] m;
  logic [5:0] matchedA, matchedB;
  begin
    compare_edges = 1;
    matchedA = 6'b0;
    matchedB = 6'b0;
    for (int i = 0; i < m; i++) begin
      logic foundA;
      foundA = 0;
      for (int j = 0; j < m; j++) begin
        if (!matchedA[i] && !matchedB[j]) begin
          if ((edgesA[i][3:2] == edgesB[j][3:2] &&
              edgesA[i][1:0] == edgesB[j][1:0]) ||
             (edgesA[i][3:2] == edgesB[j][1:0] &&
              edgesA[i][1:0] == edgesB[j][3:2])) begin
            matchedA[i] = 1;
            matchedB[j] = 1;
            foundA = 1;
            break;
          end
        end
      end
      if (!foundA) compare_edges = 0;
    end
    // Check if all desired edges matched
    if (matchedB !== {6{1'b1}}) compare_edges = 0;
  end
endfunction

// Edge transformation logic
function [3:0] transform;
  input [1:0] floor;
  input [3:0] edge;
  input button_type;
  reg [1:0] a, b, new_b;
  begin
    a = edge[3:2];
    b = edge[1:0];
    
    // Apply red button once (for green, apply twice)
    if ((a == floor) || (b == floor)) begin
      if (a == floor) begin
        // Transform b
        new_b = (b + 1) % 4;
        if (new_b == floor) new_b = (b + 2) % 4;
        edge = {a, new_b};
      end
      if (b == floor) begin
        // Transform a
        new_b = (a + 1) % 4;
        if (new_b == floor) new_b = (a + 2) % 4;
        edge = {new_b, b};
      end
    end
    
    // Apply green button (apply red twice)
    if (button_type) begin
      if ((a == floor) || (b == floor)) begin
        if (a == floor) begin
          new_b = (b + 1) % 4;
          if (new_b == floor) new_b = (b + 2) % 4;
          new_b = (new_b + 1) % 4;
          if (new_b == floor) new_b = (new_b + 2) % 4;
          edge = {a, new_b};
        end
        if (b == floor) begin
          new_b = (a + 1) % 4;
          if (new_b == floor) new_b = (a + 2) % 4;
          new_b = (new_b + 1) % 4;
          if (new_b == floor) new_b = (new_b + 2) % 4;
          edge = {new_b, b};
        end
      end
    end
    transform = edge;
  end
endfunction

// Apply transform to all edges
function [5:0][3:0] apply_press;
  input [5:0][3:0] edges;
  input [1:0] floor;
  input button_type;
  begin
    for (int i = 0; i < 6; i++) begin
      apply_press[i] = transform(floor, edges[i], button_type);
    end
  end
endfunction

// Main FSM
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    working_edges <= 0;
    done <= 0;
    valid <= 0;
    step_counter <= 0;
    sequence_type <= 0;
    sequence_floor <= 0;
    for (int i = 0; i < 16; i++) begin
      seq_type[i] <= 0;
      seq_floor[i] <= 0;
    end
  end
  else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= INIT;
          done <= 0;
          valid <= 0;
        end
      end
      
      INIT: begin
        working_edges <= current_edges;
        step_counter <= 0;
        floor_index <= 0;
        press_type <= 0;
        state <= CHECK_MATCH;
      end
      
      CHECK_MATCH: begin
        if (compare_edges(working_edges, desired_edges, M)) begin
          solution_length <= step_counter;
          valid <= (step_counter != 0);
          done <= 1;
          state <= DONE;
        end
        else if (step_counter < 16) begin
          state <= PRESS_RED;
          floor_index <= 0;
        end
        else begin
          valid <= 0;
          done <= 1;
          state <= DONE;
        end
      end
      
      PRESS_RED: begin
        working_edges <= apply_press(working_edges, floor_index, 0);
        state <= UPDATE_STATE;
      end
      
      PRESS_GREEN: begin
        working_edges <= apply_press(working_edges, floor_index, 1);
        state <= UPDATE_STATE;
      end
      
      UPDATE_STATE: begin
        seq_floor[step_counter] <= floor_index;
        seq_type[step_counter] <= press_type;
        step_counter <= step_counter + 1;
        state <= CHECK_MATCH;
      end
      
      DONE: begin
        if (step_counter > 0) begin
          for (int i = 0; i < 16; i++) begin
            sequence_type[i] = seq_type[i];
            sequence_floor[i] = seq_floor[i];
          end
        end
        state <= IDLE;
      end
      
      default: state <= IDLE;
    endcase
  end
end

// FSM next floor logic
always_comb begin
  next_state = state;
  if (state == PRESS_RED) begin
    if (floor_index < 3) begin
      floor_index = floor_index + 1;
      next_state = PRESS_RED;
    end
    else begin
      press_type = 1;
      floor_index = 0;
      next_state = PRESS_GREEN;
    end
  end
  else if (state == PRESS_GREEN) begin
    if (floor_index < 3) begin
      floor_index = floor_index + 1;
      next_state = PRESS_GREEN;
    end
    else begin
      next_state = UPDATE_STATE;
    end
  end
end

endmodule