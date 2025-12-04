module xor_odd_pair_counter(input [3:0] A[0:7], output logic [4:0] odd_pair_count);
  logic [3:0] odd_count;
  logic [3:0] even_count;
  always_comb begin
    odd_count = 4'b0;
    for (int i = 0; i < 8; i++) begin
      if (A[i][0]) odd_count++;
    end
    even_count = 8 - odd_count;
    odd_pair_count = odd_count * even_count;
  end
endmodule