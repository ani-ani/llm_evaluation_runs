module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);
  reg [255:0] next_q;
  always @(*) begin
    for(int row = 0; row < 16; row++) begin
      for(int col = 0; col < 16; col++) begin
        int rr, cc;
        int count = 0;
        for(int dr = -1; dr <= 1; dr++) begin
          for(int dc = -1; dc <= 1; dc++) begin
            if(!(dr == 0 && dc == 0)) begin
              rr = (row + dr + 16) % 16;
              cc = (col + dc + 16) % 16;
              if(q[rr*16 + cc]) count++;
            end
          end
        end
        if(count == 3) next_q[row*16 + col] = 1'b1;
        else if(count == 2) next_q[row*16 + col] = q[row*16 + col];
        else next_q[row*16 + col] = 1'b0;
      end
    end
  end
  always @(posedge clk) begin
    if(load) q <= data;
    else q <= next_q;
  end
endmodule