module longest_interesting_subsequence(
  input [15:0] S,
  input [15:0] A [0:7],
  output reg [3:0] result [0:7]
);

reg [15:0] sum_block [0:7][0:7];

generate
  genvar j, k;
  for (j=0; j<8; j=j+1) begin
    sum_block[j][0] = 16'd0;
    sum_block[j][1] = A[j];
    for (k=2; k<8; k=k+1) begin
      if (j+k-1 < 8) begin
        sum_block[j][k] = sum_block[j][k-1] + A[j+k-1];
      end
    end
  end
endgenerate

reg cond [0:7][0:3];

generate
  genvar i, k1;
  for (i=0; i<8; i=i+1) begin
    for (k1=0; k1<4; k1=k1+1) begin
      if (i+2*(k1+1) <= 8) begin
        cond[i][k1] = ( (sum_block[i][k1+1] <= S) && (sum_block[i+k1+1][k1+1] <= S) );
      end else begin
        cond[i][k1] = 1'b0;
      end
    end
  end
endgenerate

generate
  genvar i;
  for (i=0; i<8; i=i+1) begin
    always @(*) begin
      if (cond[i][3])
        result[i] = 4'd8;
      else if (cond[i][2])
        result[i] = 4'd6;
      else if (cond[i][1])
        result[i] = 4'd4;
      else if (cond[i][0])
        result[i] = 4'd2;
      else
        result[i] = 4'd0;
    end
  end
endgenerate

endmodule