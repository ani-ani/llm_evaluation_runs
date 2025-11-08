module TopModule(input clk, input load, input [511:0] data, output reg [511:0] q);
  wire [511:0] next_state;
  
  genvar i;
  generate
    for (i = 0; i < 512; i = i + 1) begin : rule110
      wire left = (i == 511) ? 1'b0 : q[i+1];
      wire center = q[i];
      wire right = (i == 0) ? 1'b0 : q[i-1];
      assign next_state[i] = center ? (left ? ~right : 1'b1) : right;
    end
  endgenerate
  
  always @(posedge clk) begin
    if (load)
      q <= data;
    else
      q <= next_state;
  end
endmodule