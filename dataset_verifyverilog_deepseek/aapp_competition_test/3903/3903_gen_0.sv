module three_states_router(
  input clk,
  input rst_n,
  input start,
  input [2:0] grid [0:7][0:7],
  output reg [7:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam RUN = 2'b01;
  localparam COMPUTE = 2'b10;
  localparam DONE = 2'b11;
  reg [1:0] state;

  reg [2:0] grid_reg [0:7][0:7];
  reg [7:0] dist0 [0:7][0:7];
  reg [7:0] dist1 [0:7][0:7];
  reg [7:0] dist2 [0:7][0:7];
  reg [6:0] cycle_count;
  reg [7:0] min_total;

  integer x, y;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      done <= 0;
      result <= 255;
      state <= IDLE;
      cycle_count <= 0;
      for (x = 0; x < 8; x++) begin
        for (y = 0; y < 8; y++) begin
          grid_reg[x][y] <= 0;
          dist0[x][y] <= 8'hFF;
          dist1[x][y] <= 8'hFF;
          dist2[x][y] <= 8'hFF;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            for (x = 0; x < 8; x++) begin
              for (y = 0; y < 8; y++) begin
                grid_reg[x][y] <= grid[x][y];
                if (grid[x][y][1:0] == 2'b01) begin
                  dist0[x][y] <= 0;
                  dist1[x][y] <= 8'hFF;
                  dist2[x][y] <= 8'hFF;
                end else if(grid[x][y][1:0] == 2'b10) begin
                  dist0[x][y] <= 8'hFF;
                  dist1[x][y] <= 0;
                  dist2[x][y] <= 8'hFF;
                end else if(grid[x][y][1:0] == 2'b11) begin
                  dist0[x][y] <= 8'hFF;
                  dist1[x][y] <= 8'hFF;
                  dist2[x][y] <= 0;
                end else begin
                  dist0[x][y] <= 8'hFF;
                  dist1[x][y] <= 8'hFF;
                  dist2[x][y] <= 8'hFF;
                end
              end
            end
            state <= RUN;
            cycle_count <= 0;
          end
        end

        RUN: begin
          for (x = 0; x < 8; x++) begin
            for (y = 0; y < 8; y++) begin
              reg [7:0] nd0, nd1, nd2;
              reg [7:0] cost;
              reg is_traversable;
              nd0 = dist0[x][y];
              nd1 = dist1[x][y];
              nd2 = dist2[x][y];
              is_traversable = grid_reg[x][y][2] || (|grid_reg[x][y][1:0]);
              cost = grid_reg[x][y][2] ? 8'd1 : 8'd0;

              if (is_traversable) begin
                if (x > 0) begin
                  nd0 = (dist0[x-1][y] + cost) < nd0 ?(dist0[x-1][y] + cost):nd0;
                  nd1 = (dist1[x-1][y] + cost) < nd1 ?(dist1[x-1][y] + cost):nd1;
                  nd2 = (dist2[x-1][y] + cost) < nd2 ?(dist2[x-1][y] + cost):nd2;
                end
                if (x < 7) begin
                  nd0 = (dist0[x+1][y] + cost) < nd0 ?(dist0[x+1][y] + cost):nd0;
                  nd1 = (dist1[x+1][y] + cost) < nd1 ?(dist1[x+1][y] + cost):nd1;
                  nd2 = (dist2[x+1][y] + cost) < nd2 ?(dist2[x+1][y] + cost):nd2;
                end
                if (y > 0) begin
                  nd0 = (dist0[x][y-1] + cost) < nd0 ?(dist0[x][y-1] + cost):nd0;
                  nd1 = (dist1[x][y-1] + cost) < nd1 ?(dist1[x][y-1] + cost):nd1;
                  nd2 = (dist2[x][y-1] + cost) < nd2 ?(dist2[x][y-1] + cost):nd2;
                end
                if (y < 7) begin
                  nd0 = (dist0[x][y+1] + cost) < nd0 ?(dist0[x][y+1] + cost):nd0;
                  nd1 = (dist1[x][y+1] + cost) < nd1 ?(dist1[x][y+1] + cost):nd1;
                  nd2 = (dist2[x][y+1] + cost) < nd2 ?(dist2[x][y+1] + cost):nd2;
                end
              end
              dist0[x][y] <= nd0;
              dist1[x][y] <= nd1;
              dist2[x][y] <= nd2;
            end
          end

          if (cycle_count < 63) begin
            cycle_count <= cycle_count + 1;
          end else begin
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          min_total = 255;
          for (x = 0; x < 8; x++) begin
            for (y = 0; y < 8; y++) begin
              if (dist0[x][y] != 8'hFF && dist1[x][y] != 8'hFF && dist2[x][y] != 8'hFF) begin
                reg [7:0] sum;
                sum = dist0[x][y] + dist1[x][y] + dist2[x][y];
                if (sum < min_total) min_total = sum;
              end
            end
          end
          result <= (min_total < 255) ? min_total : 255;
          done <= 1;
          state <= DONE;
        end

        DONE: begin
          if (~start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end
endmodule