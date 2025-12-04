module defective_cell_enclosure(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_cells,
  input [7:0][2:0][1:0] cell_coords,
  output reg [7:0] panels,
  output reg done
);

  typedef enum {IDLE, LOAD, COUNT, DONE} state_t;
  state_t state, next_state;

  reg [3:0] load_counter;
  reg [5:0] cell_counter;
  reg [7:0] panels_acc;
  reg [63:0] grid_mem;

  logic [1:0] x, y, z;
  assign x = cell_counter[1:0];
  assign y = cell_counter[3:2];
  assign z = cell_counter[5:4];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_counter <= 0;
      cell_counter <= 0;
      panels_acc <= 0;
      grid_mem <= 64'b0;
      done <= 0;
      panels <= 0;
    end
    else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            load_counter <= 0;
          end
        end

        LOAD: begin
          if (load_counter < 15) load_counter <= load_counter + 1;
          else begin
            state <= COUNT;
            cell_counter <= 0;
            panels_acc <= 0;
          end

          if (load_counter < num_cells) begin
            logic [1:0] cx, cy, cz;
            cx = cell_coords[load_counter][0];
            cy = cell_coords[load_counter][1];
            cz = cell_coords[load_counter][2];
            grid_mem[{cz, cy, cx}] <= 1'b1;
          end
        end

        COUNT: begin
          if (cell_counter < 63) cell_counter <= cell_counter + 1;
          else state <= DONE;

          if (grid_mem[cell_counter]) begin
            logic [2:0] neighbor_count;
            logic left_valid, right_valid, front_valid, back_valid, below_valid, above_valid;

            left_valid = (x != 2'b00);
            right_valid = (x != 2'b11);
            front_valid = (y != 2'b00);
            back_valid = (y != 2'b11);
            below_valid = (z != 2'b00);
            above_valid = (z != 2'b11);

            neighbor_count = 
              (left_valid && grid_mem[{z, y, x - 1}]) +
              (right_valid && grid_mem[{z, y, x + 1}]) +
              (front_valid && grid_mem[{z, y - 1, x}]) +
              (back_valid && grid_mem[{z, y + 1, x}]) +
              (below_valid && grid_mem[{z - 1, y, x}]) +
              (above_valid && grid_mem[{z + 1, y, x}]);

            panels_acc <= panels_acc + 6 - neighbor_count;
          end
        end

        DONE: begin
          panels <= panels_acc;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule