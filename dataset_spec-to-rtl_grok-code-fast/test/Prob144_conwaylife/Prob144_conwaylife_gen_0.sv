module TopModule(
  input wire clk,
  input wire load,
  input wire [255:0] data,
  output reg [255:0] q
);

  reg [255:0] next_q;

  // Combinational logic to compute next state
  always @(*) begin
    integer r, c, nr, nc, i, j, count;
    for (r = 0; r < 16; r = r + 1) begin
      for (c = 0; c < 16; c = c + 1) begin
        count = 0;
        for (i = -1; i <= 1; i = i + 1) begin
          for (j = -1; j <= 1; j = j + 1) begin
            if (!(i == 0 && j == 0)) begin
              nr = r + i;
              nc = c + j;
              // Handle toroid wrap-around
              if (nr < 0) nr = nr + 16;
              else if (nr >= 16) nr = nr - 16;
              if (nc < 0) nc = nc + 16;
              else if (nc >= 16) nc = nc - 16;
              // Count live neighbors
              if (q[nr * 16 + nc]) count = count + 1;
            end
          end
        end
        // Apply Game of Life rules
        if (count <= 1) begin
          next_q[r * 16 + c] = 1'b0;
        end else if (count == 2) begin
          next_q[r * 16 + c] = q[r * 16 + c];
        end else if (count == 3) begin
          next_q[r * 16 + c] = 1'b1;
        end else begin
          next_q[r * 16 + c] = 1'b0;
        end
      end
    end
  end

  // Sequential logic to update q on clock edge
  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      q <= next_q;
    end
  end

endmodule