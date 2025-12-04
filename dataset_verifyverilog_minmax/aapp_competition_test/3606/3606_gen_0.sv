module frog_jump(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] K,
  input [127:0] plant_x,
  input [127:0] plant_y,
  input [31:0] directions,
  output reg [15:0] final_x,
  output reg [15:0] final_y,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam RUN = 2'b01;
  localparam DONE = 2'b10;

  // Registers
  reg [1:0] state;
  reg [3:0] jump_counter;
  reg [31:0] dir_shift_reg;
  reg [15:0] plant_x_reg [0:7];
  reg [15:0] plant_y_reg [0:7];
  reg [7:0] valid;
  reg [2:0] current_index;
  reg [15:0] current_x, current_y;
  reg [1:0] current_dir;

  // Combinational block variables
  reg [3:0] best_index;
  reg [15:0] next_x, next_y;
  reg [2:0] next_index;
  reg [7:0] next_valid;
  integer i;

  // Combinational block for candidate search
  always_comb 
  begin
    best_index = 4'd8;
    for (i = 0; i < 8; i = i + 1) 
    begin
      if (i < N && valid[i] && (i != current_index)) 
      begin
        case (current_dir)
          2'b00: // A: same y, positive x
            if (plant_y_reg[i] == current_y && plant_x_reg[i] > current_x)
              if (best_index > i) best_index = i;
          2'b01: // B: same x, positive y
            if (plant_x_reg[i] == current_x && plant_y_reg[i] > current_y)
              if (best_index > i) best_index = i;
          2'b10: // C: same y, negative x
            if (plant_y_reg[i] == current_y && plant_x_reg[i] < current_x)
              if (best_index > i) best_index = i;
          2'b11: // D: same x, negative y
            if (plant_x_reg[i] == current_x && plant_y_reg[i] < current_y)
              if (best_index > i) best_index = i;
        endcase
      end
    end

    if (best_index != 4'd8) 
    begin
      next_index = best_index;
      next_x = plant_x_reg[best_index];
      next_y = plant_y_reg[best_index];
      next_valid = valid;
      next_valid[current_index] = 1'b0; // Invalidate current plant
    end
    else 
    begin
      next_index = current_index;
      next_x = current_x;
      next_y = current_y;
      next_valid = valid;
    end
  end

  // Clocked block
  always @(posedge clk or negedge rst_n) 
  begin
    if (!rst_n) 
    begin
      state <= IDLE;
      done <= 0;
      final_x <= 0;
      final_y <= 0;
      jump_counter <= 0;
      dir_shift_reg <= 0;
      current_index <= 0;
      current_x <= 0;
      current_y <= 0;
      current_dir <= 0;
      valid <= 0;
    end
    else 
    begin
      case (state)
        IDLE: 
        begin
          if (start) 
          begin
            // Unpack plants
            for (i = 0; i < 8; i = i + 1) 
            begin
              plant_x_reg[i] = plant_x >> (16 * i);
              plant_y_reg[i] = plant_y >> (16 * i);
            end
            // Initialize valid flags
            for (i = 0; i < 8; i = i + 1) 
            begin
              if (i < N) valid[i] = 1'b1;
              else valid[i] = 1'b0;
            end
            current_index = 3'd0;
            current_x = plant_x_reg[0];
            current_y = plant_y_reg[0];
            jump_counter = 4'd0;
            dir_shift_reg = directions;
            current_dir = 2'b00;
            done = 1'b0;
            final_x = 0;
            final_y = 0;
            state = RUN;
          end
        end
        RUN: 
        begin
          if (jump_counter < K) 
          begin
            current_dir <= dir_shift_reg[31:30];
            dir_shift_reg <= dir_shift_reg << 2;
            
            current_index <= next_index;
            current_x <= next_x;
            current_y <= next_y;
            valid <= next_valid;
            
            jump_counter <= jump_counter + 1;
            
            if (jump_counter + 1 == K) 
            begin
              state = DONE;
            end
          end
          else 
          begin
            state = DONE;
          end
        end
        DONE: 
        begin
          done = 1'b1;
          final_x = current_x;
          final_y = current_y;
          
          if (start) 
          begin
            state = IDLE;
          end
        end
      endcase
    end
  end
endmodule
