module TopModule(
  input clk,
  input load,
  input [511:0] data,
  output reg [511:0] q
);
  always @(posedge clk) begin
    if (load) begin
      q <= data;
    end else begin
      integer i;
      reg next_bit;
      reg [511:0] next_q;
      for (i = 0; i < 512; i = i + 1) begin
        reg left = (i > 0) ? q[i-1] : 1'b0;
        reg center = q[i];
        reg right = (i < 511) ? q[i+1] : 1'b0;
        if (left & center & right) begin
          next_bit = 1'b0;
        end else if (left & center & ~right) begin
          next_bit = 1'b1;
        end else if (left & ~center & right) begin
          next_bit = 1'b1;
        end else if (left & ~center & ~right) begin
          next_bit = 1'b0;
        end else if (~left & center & right) begin
          next_bit = 1'b1;
        end else if (~left & center & ~right) begin
          next_bit = 1'b1;
        end else if (~left & ~center & right) begin
          next_bit = 1'b1;
        end else begin
          next_bit = 1'b0;
        end
        next_q[i] = next_bit;
      end
      q <= next_q;
    end
  end
endmodule