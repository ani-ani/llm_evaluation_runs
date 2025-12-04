module char_counter(input [15:0][7:0] str_bytes, output reg [3:0] count);
  always_comb begin
    count = 4'd15;
    for (int i = 0; i < 16; i++) begin
      if (count == 4'd15 && str_bytes[i] == 8'h00) count = i;
    end
  end
endmodule