module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);
  reg [255:0] next_q;
  integer r, c, count, nr, nc;
  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      for (r = 0; r < 16; r = r + 1) begin
        for (c = 0; c < 16; c = c + 1) begin
          count = 0;
          for (integer dr = -1; dr <= 1; dr = dr + 1) begin
            for (integer dc = -1; dc <= 1; dc = dc + 1) begin
              if (dr != 0 || dc != 0) begin
                nr = (r + dr + 16) % 16;
                nc = (c + dc + 16) % 16;
                count = count + q[nr * 16 + nc];
              end
            end
          end
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
      q <= next_q;
    end
  end
endmodule