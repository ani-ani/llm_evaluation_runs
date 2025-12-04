module snowblower_area(
  input clk,               // clock signal
  input rst_n,             // active-low reset
  input start,             // start computation
  input [63:0] max_sq,     // precomputed max squared distance (Q16.16 fixed-point)
  input [63:0] min_sq,     // precomputed min squared distance (Q16.16 fixed-point)
  output reg [63:0] diff   // max_sq - min_sq (Q16.16 fixed-point)
);

  // Sequential module with 1-clock latency
  // Result is valid 1 clock cycle after start assertion
  always @(posedge clk) begin
    if (!rst_n) begin
      diff <= 64'h0;              // reset diff when rst_n is low
    end else if (start) begin
      diff <= max_sq - min_sq;    // compute the difference on start
    end
  end

endmodule
