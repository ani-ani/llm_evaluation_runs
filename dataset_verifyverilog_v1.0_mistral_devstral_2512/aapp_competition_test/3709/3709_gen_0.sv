module interesting_problemset (
  input [2:0] k,
  input [15:0] presence,
  output reg ans
);

  always @(*) begin
    ans = 1'b0;
    
    if (presence[0]) begin
      ans = 1'b1;
    end
    else if (k == 3'd1) begin
      ans = 1'b0;
    end
    else begin
      integer i;
      integer j;
      for (i = 0; i < 16; i = i + 1) begin
        for (j = i + 1; j < 16; j = j + 1) begin
          if (presence[i] && presence[j] && ((i & j) == 0)) begin
            ans = 1'b1;
          end
        end
      end
    end
  end
endmodule