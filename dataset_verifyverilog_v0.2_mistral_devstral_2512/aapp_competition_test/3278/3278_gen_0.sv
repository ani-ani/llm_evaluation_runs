module frog_tower (
  input clk,
  input rst_n,
  input start,
  input [5:0] frog_count,
  input [15:0] frog_data [0:15],
  output reg [7:0] tower_position,
  output reg [7:0] tower_size,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] LOAD_FROGS = 2'b01;
  localparam [1:0] FIND_MAX_TOWER = 2'b10;
  localparam [1:0] DONE_STATE = 2'b11;

  reg [1:0] state = IDLE;
  reg [7:0] position_counter = 0;
  reg [7:0] current_position = 0;
  reg [7:0] current_count = 0;
  reg [7:0] max_count = 0;
  reg [7:0] max_position = 0;
  reg [3:0] frog_index = 0;
  reg [7:0] x_i = 0;
  reg [7:0] d_i = 0;
  reg [7:0] diff = 0;
  reg [7:0] remainder = 0;
  reg [7:0] frog_reg [0:15];
  reg [7:0] jump_dist_reg [0:15];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      position_counter <= 0;
      current_position <= 0;
      current_count <= 0;
      max_count <= 0;
      max_position <= 0;
      frog_index <= 0;
      x_i <= 0;
      d_i <= 0;
      diff <= 0;
      remainder <= 0;
      done <= 0;
      tower_position <= 0;
      tower_size <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD_FROGS;
          end
        end
        LOAD_FROGS: begin
          if (frog_index == frog_count) begin
            state <= FIND_MAX_TOWER;
            frog_index <= 0;
            current_position <= 0;
            current_count <= 0;
            max_count <= 0;
            max_position <= 0;
          end else begin
            frog_reg[frog_index] <= frog_data[frog_index][15:8];
            jump_dist_reg[frog_index] <= frog_data[frog_index][7:0];
            frog_index <= frog_index + 1;
          end
        end
        FIND_MAX_TOWER: begin
          if (position_counter == 255) begin
            state <= DONE_STATE;
            done <= 1;
            tower_position <= max_position;
            tower_size <= max_count;
          end else begin
            if (frog_index == frog_count) begin
              if (current_count > max_count || (current_count == max_count && current_position < max_position)) begin
                max_count <= current_count;
                max_position <= current_position;
              end
              current_position <= current_position + 1;
              current_count <= 0;
              frog_index <= 0;
              position_counter <= position_counter + 1;
            end else begin
              x_i <= frog_reg[frog_index];
              d_i <= jump_dist_reg[frog_index];
              diff <= current_position - x_i;
              if (current_position >= x_i && d_i != 0) begin
                remainder <= diff % d_i;
                if (remainder == 0) begin
                  current_count <= current_count + 1;
                end
              end
              frog_index <= frog_index + 1;
            end
          end
        end
        DONE_STATE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule