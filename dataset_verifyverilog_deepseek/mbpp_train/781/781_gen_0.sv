module even_divisor_count (
  input [7:0] n,
  output logic is_even
);
  
  logic [4:0] count;
  
  always_comb begin
    count = 5'b0;
    for (int i=1; i<=15; i=i+1) begin
      if (n % i == 0) begin
        if (n == i * i) begin
          count = count + 5'd1;
        end else begin
          count = count + 5'd2;
        end
      end
    end
    is_even = ~count[0];
  end
  
endmodule