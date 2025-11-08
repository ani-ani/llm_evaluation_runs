module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);
  reg [255:0] next_q;
  
  always_comb begin
    for(int r = 0; r < 16; r++) begin
      for(int c = 0; c < 16; c++) begin
        int count = 0;
        for(int dr = -1; dr <= 1; dr++) begin
          for(int dc = -1; dc <= 1; dc++) begin
            if(dr != 0 || dc != 0) begin
              int nr = (r + dr + 16) % 16;
              int nc = (c + dc + 16) % 16;
              count += q[nr * 16 + nc];
            end
          end
        end
        int bit = r * 16 + c;
        logic current = q[bit];
        if(count < 2 || count > 3) next_q[bit] = 1'b0;
        else if(count == 3) next_q[bit] = 1'b1;
        else next_q[bit] = current;
      end
    end
  end
  
  always_ff @(posedge clk) begin
    if(load) q <= data;
    else q <= next_q;
  end
endmodule