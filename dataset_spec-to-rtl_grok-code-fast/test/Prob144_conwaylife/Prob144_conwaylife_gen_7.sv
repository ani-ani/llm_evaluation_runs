module TopModule(
  input clk,
  input load,
  input [255:0] data,
  output reg [255:0] q
);
  wire [255:0] next_q;
  always_comb begin
    for(int i = 0; i < 16; i++) begin
      for(int j = 0; j < 16; j++) begin
        int sum = 0;
        sum += q[((i - 1 + 16) % 16 * 16) + ((j - 1 + 16) % 16)];
        sum += q[((i - 1 + 16) % 16 * 16) + j];
        sum += q[((i - 1 + 16) % 16 * 16) + ((j + 1) % 16)];
        sum += q[(i * 16) + ((j - 1 + 16) % 16)];
        sum += q[(i * 16) + ((j + 1) % 16)];
        sum += q[((i + 1) % 16 * 16) + ((j - 1 + 16) % 16)];
        sum += q[((i + 1) % 16 * 16) + j];
        sum += q[((i + 1) % 16 * 16) + ((j + 1) % 16)];
        next_q[(i * 16) + j] = (sum == 2 && q[(i * 16) + j]) || (sum == 3);
      end
    end
  end
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_q;
  end
endmodule