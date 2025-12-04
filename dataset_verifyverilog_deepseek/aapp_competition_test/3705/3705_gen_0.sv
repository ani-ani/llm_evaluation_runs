module phone_number_counter(
  input [4:0] n,
  input [127:0] s,
  output reg [1:0] count
);

  always @* begin
    integer i;
    reg [5:0] temp_count_8s = 0;
    reg [1:0] temp_floor_div;
    
    // Count '8's in first n digits
    for (i = 0; i < 32; i = i + 1) begin
      if (i < n) begin
        temp_count_8s = temp_count_8s + (s[127 - 4*i -: 4] == 4'b1000);
      end
    end
    
    // Calculate floor(n/11)
    if (n >= 22) begin
      temp_floor_div = 2'd2;
    end else if (n >= 11) begin
      temp_floor_div = 2'd1;
    end else begin
      temp_floor_div = 2'd0;
    end
    
    // Output minimum of count_8s and floor_div
    if (temp_count_8s < temp_floor_div) begin
      count = temp_count_8s[1:0];
    end else begin
      count = temp_floor_div;
    end
  end
endmodule