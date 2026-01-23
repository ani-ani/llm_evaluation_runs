module pacman_ice_cleaning (
   input clk,
   input rst_n,
   input start,
   input [3:0] r, input [3:0] c,
   input [3:0] start_i, input [3:0] start_j,
   input [5:0] n,
   output reg [7:0] ram_write_addr,
   output reg [7:0] ram_write_data,
   output reg ram_write_en,
   output reg done
);

reg [3:0] rows, cols;
reg [2:0] current_row, current_col;
reg [1:0] direction;
reg [7:0] current_color;
reg [5:0] stepSize, outer_count, inner_count;
reg [2:0] state;

localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam EXEC_LOOP = 3'd2;
localparam MOVE_STEPS = 3'd3;
localparam ROTATE_STEP = 3'd4;
localparam DONE = 3'd5;

always @(posedge clk) begin
   if (!rst_n) begin
      rows <= 4'd0;
      cols <= 4'd0;
      current_row <= 3'd0;
      current_col <= 3'd0;
      direction <= 2'd0;
      current_color <= 8'h41;
      stepSize <= 4'd1;
      outer_count <= 6'd0;
      inner_count <= 6'd0;
      state <= IDLE;
      ram_write_addr <= 8'd0;
      ram_write_data <= 8'd0;
      ram_write_en <= 1'b0;
      done <= 1'b0;
   end else begin
      case(state)
         IDLE: begin
            if (start) begin
               rows <= r;
               cols <= c;
               current_row <= start_i - 1;
               current_col <= start_j - 1;
               state <= INIT;
            end
         end
         INIT: begin
            inner_count <= stepSize;
            state <= MOVE_STEPS;
         end
         EXEC_LOOP: begin
            if (outer_count == 0) begin
               ram_write_addr <= current_row * cols + current_col;
               ram_write_data <= 8'h40;
               ram_write_en <= 1'b1;
               done <= 1'b1;
               state <= DONE;
            end else if (inner_count == 0) begin
               state <= ROTATE_STEP;
            end else begin
               state <= EXEC_LOOP;
            end
         end
         MOVE_STEPS: begin
            int delta_row, delta_col;
            case(direction)
               2'd0: delta_row = -1; delta_col = 0;
               2'd1: delta_row = 0; delta_col = 1;
               2'd2: delta_row = 1; delta_col = 0;
               2'd3: delta_row = 0; delta_col = -1;
            endcase
            int new_row = current_row + delta_row;
            int new_col = current_col + delta_col;
            new_row = (new_row + rows) % rows;
            new_col = (new_col + cols) % cols;
            current_row <= new_row;
            current_col <= new_col;
            ram_write_addr <= current_row * cols + current_col;
            ram_write_data <= current_color;
            ram_write_en <= 1'b1;
            current_color <= (current_color - 8'h41 + 1) % 26 + 8'h41;
            inner_count <= inner_count - 1;
            if (inner_count == 0) begin
               state <= ROTATE_STEP;
            end else begin
               state <= MOVE_STEPS;
            end
         end
         ROTATE_STEP: begin
            direction <= (direction + 1) % 4;
            stepSize <= stepSize + 1;
            outer_count <= outer_count - 1;
            if (outer_count == 0) begin
               ram_write_addr <= current_row * cols + current_col;
               ram_write_data <= 8'h40;
               ram_write_en <= 1'b1;
               done <= 1'b1;
               state <= DONE;
            end else begin
               inner_count <= stepSize;
               state <= MOVE_STEPS;
            end
         end
         DONE: begin
            state <= DONE;
         end
         default: state <= IDLE;
      endcase
   end
endmodule