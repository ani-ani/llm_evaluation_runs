module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output [255:0] q
);

  reg [255:0] q_reg;
  assign q = q_reg;

  always @(posedge clk) begin
    if (load) begin
      q_reg <= data;
    end else begin
      reg [255:0] next_q;
      integer r, c;
      for (r=0; r<16; r=r+1) begin
        for (c=0; c<16; c=c+1) begin
          integer count = 0;
          integer nr, nc;
          for (integer dr=-1; dr<=1; dr=dr+1) begin
            for (integer dc=-1; dc<=1; dc=dc+1) begin
              if (!(dr==0 && dc==0)) begin
                nr = (r + dr + 16) % 16;
                nc = (c + dc + 16) % 16;
                count = count + q_reg[nr*16 + nc];
              end
            end
          end
          if (count <=1) begin
            next_q[r*16 + c] = 0;
          end else if (count == 2) begin
            next_q[r*16 + c] = q_reg[r*16 + c];
          end else if (count == 3) begin
            next_q[r*16 + c] = 1;
          end else begin
            next_q[r*16 + c] = 0;
          end
        end
      end
      q_reg <= next_q;
    end
  end

endmodule