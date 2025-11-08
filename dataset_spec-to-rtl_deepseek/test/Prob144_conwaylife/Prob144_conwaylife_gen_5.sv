module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);

  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      reg [255:0] next_q;
      int count;
      for (int i = 0; i < 16; i++) begin
        for (int j = 0; j < 16; j++) begin
          count = 0;
          for (int di = -1; di <= 1; di++) begin
            for (int dj = -1; dj <= 1; dj++) begin
              if (di == 0 && dj == 0) continue;
              int ni = (i + di + 16) % 16;
              int nj = (j + dj + 16) % 16;
              if (q[ni*16 + nj]) count++;
            end
          end
          if (count <= 1) begin
            next_q[i*16 + j] = 0;
          end else if (count == 2) begin
            next_q[i*16 + j] = q[i*16 + j];
          end else if (count == 3) begin
            next_q[i*16 + j] = 1;
          end else begin
            next_q[i*16 + j] = 0;
          end
        end
      end
      q <= next_q;
    end
  end
endmodule