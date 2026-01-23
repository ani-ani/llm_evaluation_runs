module max_hexagon_perimeter (
   input [5:0] n,
   input [7:0][15:0] x,
   input [7:0][15:0] y,
   output [31:0] perimeter
);

function [31:0] sqrt_approx;
   input [31:0] s;
   begin
      sqrt_approx = s >> 1;
   end
endfunction

always @(*) begin
   perimeter = 32'b0;
   if(n ==6) begin
      wire [31:0] d0, d1, d2, d3, d4, d5;
      assign d0 = sqrt_approx( ( (signed)x[0] - (signed)x[1] )*( (signed)x[0] - (signed)x[1] ) + ( (signed)y[0] - (signed)y[1] )*( (signed)y[0] - (signed)y[1] ) );
      assign d1 = sqrt_approx( ( (signed)x[1] - (signed)x[2] )*( (signed)x[1] - (signed)x[2] ) + ( (signed)y[1] - (signed)y[2] )*( (signed)y[1] - (signed)y[2] ) );
      assign d2 = sqrt_approx( ( (signed)x[2] - (signed)x[3] )*( (signed)x[2] - (signed)x[3] ) + ( (signed)y[2] - (signed)y[3] )*( (signed)y[2] - (signed)y[3] ) );
      assign d3 = sqrt_approx( ( (signed)x[3] - (signed)x[4] )*( (signed)x[3] - (signed)x[4] ) + ( (signed)y[3] - (signed)y[4] )*( (signed)y[3] - (signed)y[4] ) );
      assign d4 = sqrt_approx( ( (signed)x[4] - (signed)x[5] )*( (signed)x[4] - (signed)x[5] ) + ( (signed)y[4] - (signed)y[5] )*( (signed)y[4] - (signed)y[5] ) );
      assign d5 = sqrt_approx( ( (signed)x[5] - (signed)x[0] )*( (signed)x[5] - (signed)x[0] ) + ( (signed)y[5] - (signed)y[0] )*( (signed)y[5] - (signed)y[0] ) );
      assign perimeter = d0 + d1 + d2 + d3 + d4 + d5;
   end
   else begin
      assign perimeter = 32'b0;
   end
end
endmodule