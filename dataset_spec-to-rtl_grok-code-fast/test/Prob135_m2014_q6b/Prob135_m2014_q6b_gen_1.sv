module TopModule(
  input [2:0] y,
  input w,
  output reg Y1
);

  always @* begin
    case ({y, w})
      4'b0000: Y1 = 1'b0;  // A, w=0 -> B, next y[1]=0
      4'b0010: Y1 = 1'b1;  // B, w=0 -> C, next y[1]=1
      4'b0100: Y1 = 1'b0;  // C, w=0 -> E, next y[1]=0
      4'b0110: Y1 = 1'b0;  // D, w=0 -> F, next y[1]=0
      4'b1000: Y1 = 1'b0;  // E, w=0 -> E, next y[1]=0
      4'b1010: Y1 = 1'b1;  // F, w=0 -> C, next y[1]=1
      4'b0001: Y1 = 1'b0;  // A, w=1 -> A, next y[1]=0
      4'b0011: Y1 = 1'b1;  // B, w=1 -> D, next y[1]=1
      4'b0101: Y1 = 1'b1;  // C, w=1 -> D, next y[1]=1
      4'b0111: Y1 = 1'b0;  // D, w=1 -> A, next y[1]=0
      4'b1001: Y1 = 1'b1;  // E, w=1 -> D, next y[1]=1
      4'b1011: Y1 = 1'b1;  // F, w=1 -> D, next y[1]=1
      default: Y1 = 1'b0;
    endcase
  end

endmodule