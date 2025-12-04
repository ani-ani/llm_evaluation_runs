module defective_cell_enclosure(
  input clk,
  input rst_n,
  input start,
  input [7:0] num_cells,
  input [7:0][5:0] cell_coords,
  output reg [7:0] panels,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam LOAD = 2'b01;
  localparam COUNT = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state;
  reg [4:0] load_cntr;
  reg [6:0] scan_cntr;
  reg [7:0] panel_count;
  reg [63:0] grid;
  integer num_neighbors;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_cntr <= 5'd0;
      scan_cntr <= 7'd0;
      panel_count <= 8'd0;
      grid <= 64'd0;
      done <= 1'b0;
      panels <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            load_cntr <= 5'd0;
            grid <= 64'd0;
          end
        end
        LOAD: begin
          if (load_cntr < 5'd16) begin
            if (load_cntr < num_cells) begin
              grid <= grid | (64'b1 << cell_coords[load_cntr]);
            end
            load_cntr <= load_cntr + 1;
          end else begin
            state <= COUNT;
            scan_cntr <= 7'd0;
            panel_count <= 8'd0;
          end
        end
        COUNT: begin
          if (scan_cntr < 7'd64) begin
            if (grid[scan_cntr]) begin
              num_neighbors = 0;
              if (scan_cntr[1:0] != 2'b11) begin
                if (grid[scan_cntr + 1]) num_neighbors = num_neighbors + 1;
              end
              if (scan_cntr[1:0] != 2'b00) begin
                if (grid[scan_cntr - 1]) num_neighbors = num_neighbors + 1;
              end
              if (scan_cntr[3:2] != 2'b11) begin
                if (grid[scan_cntr + 4]) num_neighbors = num_neighbors + 1;
              end
              if (scan_cntr[3:2] != 2'b00) begin
                if (grid[scan_cntr - 4]) num_neighbors = num_neighbors + 1;
              end
              if (scan_cntr[5:4] != 2'b11) begin
                if (grid[scan_cntr + 16]) num_neighbors = num_neighbors + 1;
              end
              if (scan_cntr[5:4] != 2'b00) begin
                if (grid[scan_cntr - 16]) num_neighbors = num_neighbors + 1;
              end
              panel_count <= panel_count + (8'd6 - num_neighbors);
            end
            scan_cntr <= scan_cntr + 1;
          end else begin
            state <= DONE;
            done <= 1'b1;
            panels <= panel_count;
          end
        end
        DONE: begin
          state <= IDLE;
          done <= 1'b0;
        end
      endcase
    end
  end
endmodule