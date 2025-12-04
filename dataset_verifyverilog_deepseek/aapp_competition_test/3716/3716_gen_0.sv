module max_triple_lcm (input [7:0] n, output [23:0] max_lcm);
  
  logic [23:0] max_val;
  logic [7:0] start;
  
  // Calculate start value (n-7 if n>=8, else 1)
  assign start = (n >= 8) ? (n - 7) : 8'd1;
    
  always_comb begin
    max_val = 0;
    for (int i = 0; i < 8; i = i + 1) begin
      for (int j = 0; j <= i; j = j + 1) begin
        for (int k = 0; k <= j; k = k + 1) begin
          logic [7:0] i_val, j_val, k_val;
          logic [23:0] current_lcm;
          i_val = start + ((7 - i) & 7);
          j_val = start + ((7 - j) & 7);
          k_val = start + ((7 - k) & 7);
          if (i_val <= n && j_val <= n && k_val <= n && k_val >= 1) begin
            current_lcm = lcm_triple(i_val, j_val, k_val);
            if (current_lcm > max_val) begin
              max_val = current_lcm;
            end
          end
        end
      end
    end
  end
  
  assign max_lcm = max_val;
  
  // 16-bit GCD function
  function automatic logic [15:0] gcd (input [15:0] a, input [15:0] b);
    logic [15:0] temp_a, temp_b;
    temp_a = a;
    temp_b = b;
    while (temp_b != 0) begin
      logic [15:0] temp;
      temp = temp_b;
      temp_b = temp_a % temp_b;
      temp_a = temp;
    end
    return temp_a;
  endfunction
  
  // LCM of three numbers (a,b,c)
  function automatic logic [23:0] lcm_triple (input [7:0] a, b, c);
    logic [15:0] b16 = {8'b0, b};
    logic [15:0] c16 = {8'b0, c};
    logic [15:0] gcd_jk = gcd(b16, c16);
    logic [15:0] lcm_jk = (b16 * c16) / gcd_jk;
    
    logic [15:0] a16 = {8'b0, a};
    logic [15:0] gcd_i_jk = gcd(a16, lcm_jk);
    
    logic [23:0] numerator = a * lcm_jk;
    logic [23:0] lcm_ijk = numerator / gcd_i_jk;
    
    return lcm_ijk;
  endfunction
  
endmodule