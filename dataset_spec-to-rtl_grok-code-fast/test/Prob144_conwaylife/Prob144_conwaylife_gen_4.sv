module TopModule(input clk, input load, input [255:0] data, output reg [255:0] q);

  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      integer x, y;
      integer dx, dy;
      integer nx, ny;
      reg [3:0] sum;
      reg next_cell;
      for (y = 0; y < 16; y = y + 1) begin
        for (x = 0; x < 16; x = x + 1) begin
          sum = 4'b0;
          for (dy = -1; dy <= 1; dy = dy + 1) begin
            for (dx = -1; dx <= 1; dx = dx + 1) begin
              if (!(dx == 0 && dy == 0)) begin
                ny = (y + dy + 16) % 16;
                nx = (x + dx + 16) % 16;
                sum = sum + q[ny * 16 + nx];
              end
            end
          end
          next_cell = (sum == 3) || (sum == 2 && q[y * 16 + x]);
          q[y * 16 + x] <= next_cell;
        end
      end
    end
  end

endmodule