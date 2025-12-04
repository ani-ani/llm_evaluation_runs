module doll_average_counter(input [15:0] p_value, input [7:0][15:0] prices, output [5:0] count);
  logic [5:0] cnt;
  assign count = cnt;

  always_comb begin
    cnt = '0;
    for (int L = 1; L <= 8; L++) begin
      for (int start = 0; start <= (8 - L); start++) begin
        logic [31:0] sum = 0;
        for (int k = 0; k < L; k++) begin
          sum += prices[start + k];
        end
        logic [31:0] threshold = p_value * L;
        if (sum >= threshold) begin
          cnt++;
        end
      end
    end
  end
endmodule