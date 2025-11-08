module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);
  logic [255:0] next;
  always_comb begin
    for (int i = 0; i < 16; i++) begin
      for (int j = 0; j < 16; j++) begin
        logic [3:0] count = 0;
        count += q[((i-1+16)%16)*16 + (j-1+16)%16];
        count += q[((i-1+16)%16)*16 + j];
        count += q[((i-1+16)%16)*16 + (j+1)%16];
        count += q[i*16 + (j-1+16)%16];
        count += q[i*16 + (j+1)%16];
        count += q[((i+1)%16)*16 + (j-1+16)%16];
        count += q[((i+1)%16)*16 + j];
        count += q[((i+1)%16)*16 + (j+1)%16];
        logic current = q[i*16 + j];
        next[i*16 + j] = (count == 4'd3) || (count == 4'd2 && current);
      end
    end
  end
  always_ff @(posedge clk) begin
    if (load) q <= data;
    else q <= next;
  end
endmodule