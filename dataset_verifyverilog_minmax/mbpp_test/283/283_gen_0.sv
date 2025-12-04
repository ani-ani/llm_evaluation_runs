module digit_frequency_check(
  input [15:0] num,
  output reg valid
);
  
  // Extract the 4 decimal digits (each 4 bits)
  wire [3:0] d0 = num[3:0];     // least significant digit
  wire [3:0] d1 = num[7:4];
  wire [3:0] d2 = num[11:8];
  wire [3:0] d3 = num[15:12];   // most significant digit
  
  // Count occurrences of each digit 0-4
  reg [2:0] count0, count1, count2, count3, count4;
  
  always @(*) begin
    // Initialize counts
    count0 = 3'b0;
    count1 = 3'b0;
    count2 = 3'b0;
    count3 = 3'b0;
    count4 = 3'b0;
    
    // Count digit 0 occurrences
    if (d0 == 4'd0) count0 = count0 + 1;
    if (d1 == 4'd0) count0 = count0 + 1;
    if (d2 == 4'd0) count0 = count0 + 1;
    if (d3 == 4'd0) count0 = count0 + 1;
    
    // Count digit 1 occurrences
    if (d0 == 4'd1) count1 = count1 + 1;
    if (d1 == 4'd1) count1 = count1 + 1;
    if (d2 == 4'd1) count1 = count1 + 1;
    if (d3 == 4'd1) count1 = count1 + 1;
    
    // Count digit 2 occurrences
    if (d0 == 4'd2) count2 = count2 + 1;
    if (d1 == 4'd2) count2 = count2 + 1;
    if (d2 == 4'd2) count2 = count2 + 1;
    if (d3 == 4'd2) count2 = count2 + 1;
    
    // Count digit 3 occurrences
    if (d0 == 4'd3) count3 = count3 + 1;
    if (d1 == 4'd3) count3 = count3 + 1;
    if (d2 == 4'd3) count3 = count3 + 1;
    if (d3 == 4'd3) count3 = count3 + 1;
    
    // Count digit 4 occurrences
    if (d0 == 4'd4) count4 = count4 + 1;
    if (d1 == 4'd4) count4 = count4 + 1;
    if (d2 == 4'd4) count4 = count4 + 1;
    if (d3 == 4'd4) count4 = count4 + 1;
  end
  
  // Check if all digit frequencies are valid
  // For digits 0-4: count <= digit value
  // For digits 5-9: always valid (max count 4 <= digit value 5-9)
  always @(*) begin
    if ((count0 <= 3'd0) && (count1 <= 3'd1) && (count2 <= 3'd2) && 
        (count3 <= 3'd3) && (count4 <= 3'd4)) begin
      valid = 1'b1;
    end else begin
      valid = 1'b0;
    end
  end
  
endmodule