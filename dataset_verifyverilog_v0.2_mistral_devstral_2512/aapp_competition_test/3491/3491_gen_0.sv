module hogwarts_staircases (
  input clk,
  input rst_n,
  input start,
  input [63:0] current_state,
  input [63:0] target_state,
  output reg [7:0] action_type,
  output reg [2:0] floor_num,
  output reg valid,
  output reg done
);

  // Parameters
  localparam N = 6;
  localparam MAX_STEPS = 128;
  localparam IDLE = 3'b000;
  localparam CALCULATE = 3'b001;
  localparam EXECUTE = 3'b010;
  localparam CHECK = 3'b011;
  localparam DONE = 3'b100;

  // State registers
  reg [2:0] state = IDLE;
  reg [63:0] curr_state;
  reg [5:0] best_diff;
  reg [3:0] best_action; // [2:0]: floor, [3]: color (0=R, 1=G)
  reg [7:0] step_count;
  reg [2:0] calc_floor;
  reg calc_color;
  reg [5:0] calc_diff;
  reg [63:0] next_state;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      action_type <= 8'h00;
      floor_num <= 3'b000;
      valid <= 1'b0;
      done <= 1'b0;
      state <= IDLE;
      curr_state <= 64'h0;
      best_diff <= 6'h3F;
      best_action <= 4'h0;
      step_count <= 8'h0;
      calc_floor <= 3'b000;
      calc_color <= 1'b0;
      calc_diff <= 6'h3F;
      next_state <= 64'h0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            curr_state <= current_state;
            step_count <= 8'h0;
            best_diff <= 6'h3F;
            calc_floor <= 3'b000;
            calc_color <= 1'b0;
          end
        end
        CALCULATE: begin
          // Calculate next state for current calc_floor and calc_color
          next_state = apply_button(curr_state, calc_floor, calc_color);
          calc_diff = hamming_distance(next_state, target_state);
          
          // Update best action if this is better
          if (calc_diff < best_diff) begin
            best_diff <= calc_diff;
            best_action <= {calc_color, calc_floor};
          end
          
          // Move to next action
          if (calc_color == 1'b0) begin
            calc_color <= 1'b1;
          end else begin
            calc_color <= 1'b0;
            if (calc_floor == 3'b101) begin
              state <= EXECUTE;
            end else begin
              calc_floor <= calc_floor + 1'b1;
            end
          end
        end
        EXECUTE: begin
          // Apply the best action
          curr_state <= apply_button(curr_state, best_action[2:0], best_action[3]);
          action_type <= best_action[3] ? 8'h47 : 8'h52; // 'G' or 'R'
          floor_num <= best_action[2:0];
          valid <= 1'b1;
          state <= CHECK;
        end
        CHECK: begin
          valid <= 1'b0;
          if (curr_state == target_state || step_count == MAX_STEPS - 1) begin
            state <= DONE;
            done <= 1'b1;
          end else begin
            state <= CALCULATE;
            step_count <= step_count + 1'b1;
            best_diff <= 6'h3F;
            calc_floor <= 3'b000;
            calc_color <= 1'b0;
          end
        end
        DONE: begin
          if (!start) begin
            done <= 1'b0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

  // Combinational function to apply button press
  function [63:0] apply_button;
    input [63:0] state_in;
    input [2:0] floor;
    input color; // 0=R, 1=G
    integer i, j, new_j;
    reg [63:0] new_state;
    
    begin
      new_state = state_in;
      
      if (color == 1'b0) begin // Red
        for (i = 0; i < N; i = i + 1) begin
          if (i != floor) begin
            if (state_in[floor * N + i]) begin
              new_j = (i + 1) % N;
              // Check for collision
              if (new_state[floor * N + new_j] && new_j != floor) begin
                new_j = (new_j + 1) % N;
              end
              new_state[floor * N + i] = 1'b0;
              new_state[floor * N + new_j] = 1'b1;
            end
          end
        end
      end else begin // Green (equivalent to 4 Red presses)
        for (j = 0; j < 4; j = j + 1) begin
          for (i = 0; i < N; i = i + 1) begin
            if (i != floor) begin
              if (new_state[floor * N + i]) begin
                new_j = (i + 1) % N;
                // Check for collision
                if (new_state[floor * N + new_j] && new_j != floor) begin
                  new_j = (new_j + 1) % N;
                end
                new_state[floor * N + i] = 1'b0;
                new_state[floor * N + new_j] = 1'b1;
              end
            end
          end
        end
      end
      apply_button = new_state;
    end
  endfunction

  // Combinational function to calculate Hamming distance
  function [5:0] hamming_distance;
    input [63:0] a;
    input [63:0] b;
    integer i;
    reg [5:0] dist;
    
    begin
      dist = 0;
      for (i = 0; i < 64; i = i + 1) begin
        if (a[i] != b[i]) begin
          dist = dist + 1'b1;
        end
      end
      hamming_distance = dist;
    end
  endfunction

endmodule