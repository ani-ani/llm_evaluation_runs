module slime_game(
  input [15:0] n,
  output reg [4:0] count,
  output reg [4:0][15:0] values
);

  integer i;
  integer j;
  
  always @* begin
    count = 0;
    for (i = 0; i < 16; i = i + 1) begin
      values[i] = 0;
    end
    
    j = 0;
    for (i = 15; i >= 0; i = i - 1) begin
      if (n[i] == 1) begin
        values[j] = i + 1;
        j = j + 1;
      end
    end
    
    count = j;
  end

endmodule