module max_triples(
  input [3:0] n,
  output reg [15:0] count
);

  // Pre-computed a[i] values for i=1 to 8
  // a[i] = i^2 - i + 1
  // a[1]=1, a[2]=3, a[3]=7, a[4]=13, a[5]=21, a[6]=31, a[7]=43, a[8]=57
  reg [5:0] a[1:8];
  
  // Combinational logic block
  always @(*) begin
    // Initialize array values
    a[1] = 6'd1;
    a[2] = 6'd3;
    a[3] = 6'd7;
    a[4] = 6'd13;
    a[5] = 6'd21;
    a[6] = 6'd31;
    a[7] = 6'd43;
    a[8] = 6'd57;
    
    // Initialize count
    count = 16'd0;
    
    // Check all triplets (i, j, k) where i < j < k
    // Only check for indices up to n
    
    // i=1
    if (n >= 3) begin
      // j=2, k=3 to n
      if (n >= 3 && ((a[1] + a[2] + a[3]) % 3 == 0)) count = count + 1;
      if (n >= 4 && ((a[1] + a[2] + a[4]) % 3 == 0)) count = count + 1;
      if (n >= 5 && ((a[1] + a[2] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[1] + a[2] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[1] + a[2] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[1] + a[2] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=3, k=4 to n
      if (n >= 4 && ((a[1] + a[3] + a[4]) % 3 == 0)) count = count + 1;
      if (n >= 5 && ((a[1] + a[3] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[1] + a[3] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[1] + a[3] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[1] + a[3] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=4, k=5 to n
      if (n >= 5 && ((a[1] + a[4] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[1] + a[4] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[1] + a[4] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[1] + a[4] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=5, k=6 to n
      if (n >= 6 && ((a[1] + a[5] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[1] + a[5] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[1] + a[5] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=6, k=7 to n
      if (n >= 7 && ((a[1] + a[6] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[1] + a[6] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=7, k=8
      if (n >= 8 && ((a[1] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
    
    // i=2
    if (n >= 4) begin
      // j=3, k=4 to n
      if (n >= 4 && ((a[2] + a[3] + a[4]) % 3 == 0)) count = count + 1;
      if (n >= 5 && ((a[2] + a[3] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[2] + a[3] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[2] + a[3] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[2] + a[3] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=4, k=5 to n
      if (n >= 5 && ((a[2] + a[4] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[2] + a[4] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[2] + a[4] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[2] + a[4] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=5, k=6 to n
      if (n >= 6 && ((a[2] + a[5] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[2] + a[5] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[2] + a[5] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=6, k=7 to n
      if (n >= 7 && ((a[2] + a[6] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[2] + a[6] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=7, k=8
      if (n >= 8 && ((a[2] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
    
    // i=3
    if (n >= 5) begin
      // j=4, k=5 to n
      if (n >= 5 && ((a[3] + a[4] + a[5]) % 3 == 0)) count = count + 1;
      if (n >= 6 && ((a[3] + a[4] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[3] + a[4] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[3] + a[4] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=5, k=6 to n
      if (n >= 6 && ((a[3] + a[5] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[3] + a[5] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[3] + a[5] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=6, k=7 to n
      if (n >= 7 && ((a[3] + a[6] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[3] + a[6] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=7, k=8
      if (n >= 8 && ((a[3] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
    
    // i=4
    if (n >= 6) begin
      // j=5, k=6 to n
      if (n >= 6 && ((a[4] + a[5] + a[6]) % 3 == 0)) count = count + 1;
      if (n >= 7 && ((a[4] + a[5] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[4] + a[5] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=6, k=7 to n
      if (n >= 7 && ((a[4] + a[6] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[4] + a[6] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=7, k=8
      if (n >= 8 && ((a[4] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
    
    // i=5
    if (n >= 7) begin
      // j=6, k=7 to n
      if (n >= 7 && ((a[5] + a[6] + a[7]) % 3 == 0)) count = count + 1;
      if (n >= 8 && ((a[5] + a[6] + a[8]) % 3 == 0)) count = count + 1;
      
      // j=7, k=8
      if (n >= 8 && ((a[5] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
    
    // i=6
    if (n >= 8) begin
      // j=7, k=8
      if (n >= 8 && ((a[6] + a[7] + a[8]) % 3 == 0)) count = count + 1;
    end
  end

endmodule
