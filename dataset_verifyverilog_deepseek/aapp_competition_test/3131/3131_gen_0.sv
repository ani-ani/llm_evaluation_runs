module piano_key_sum(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] K,
  input [31:0] keys [7:0],
  output reg [31:0] result,
  output reg done
);

  reg [7:0] comb_mask;
  reg computing;
  wire [7:0] masked_comb = comb_mask & ((1 << N) - 1);
  
  function automatic [3:0] count_bits(input [7:0] x);
    count_bits = 0;
    for (int i=0; i<8; i++)
      count_bits += x[i];
  endfunction
  
  wire [3:0] bit_count = count_bits(masked_comb);
  
  function automatic [31:0] find_max(input [31:0] keys [7:0], input [7:0] mask);
    find_max = 0;
    for (int i=0; i<8; i++) begin
      if (mask[i] && (keys[i] > find_max))
        find_max = keys[i];
    end
  endfunction
  
  wire [31:0] current_max = find_max(keys, masked_comb);
  
  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
      computing <= 0;
      comb_mask <= 0;
    end else begin
      if (start && !computing) begin
        computing <= 1;
        done <= 0;
        comb_mask <= 0;
        result <= 0;
      end else if (computing) begin
        if (bit_count == K) begin
          result <= (result + current_max) % 32'h3B9ACA07;
        end
        comb_mask <= comb_mask + 1;
        if (comb_mask == 8'hFF) begin
          computing <= 0;
          done <= 1;
        end
      end
    end
  end

endmodule