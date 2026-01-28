module interesting_problemset (
  input [2:0] k,         // Number of teams (1-4)
  input [15:0] presence, // Bit i=1 if mask i exists
  output reg ans         // 1=Valid subset exists
);

always @(*) begin
  // Condition 1: Problem unknown to all teams exists
  if (presence[0]) 
    ans = 1'b1;
  // Condition 2: For k=1, only mask 0 works
  else if (k == 3'b001) 
    ans = 1'b0;
  // Condition 3: Check for disjoint pair
  else begin
    ans = 1'b0;
    for (integer i = 0; i < 16; i = i + 1) begin
      for (integer j = i + 1; j < 16; j = j + 1) begin
        if (presence[i] && presence[j] && ((i & j) == 0))
          ans = 1'b1;
      end
    end
  end
end
endmodule