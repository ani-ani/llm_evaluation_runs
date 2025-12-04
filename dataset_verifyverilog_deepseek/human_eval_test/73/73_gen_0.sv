module smallest_change(input [3:0] arr_len, input [7:0] arr [0:7], output reg [2:0] changes);
  always_comb begin
    changes = 0;
    for (int j = 0; j < 4; j++) begin
      if (j < (arr_len >> 1)) begin
        if (arr[j] != arr[arr_len - 1 - j]) changes = changes + 1;
      end
    end
  end
endmodule