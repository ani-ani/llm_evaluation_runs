module weight_identifier(input clk, input rst_n, input start, input [3:0] n, input [31:0] weights, output reg [3:0] result, output reg done);
  reg [7:0] cycle_count;
  reg [3:0] w[7:0];
  reg [127:0] bitmap[8:1];
  reg [8:1] duplicate;
  reg [7:0] valid;
  
  function automatic [3:0] popcount(input [7:0] bits);
    popcount = $countbits(bits, 1'b1);
  endfunction
  
  function automatic [7:0] compute_sum(input [7:0] idx);
    compute_sum = 0;
    for (integer i=0; i<8; i=i+1)
      if (idx[i]) compute_sum += w[i];
  endfunction
  
  function automatic [7:0] binom(input [3:0] cnt, input [3:0] k);
    case ({cnt,k})
      8'h11: binom=1;
      8'h21: binom=2; 8'h22: binom=1;
      8'h31: binom=3; 8'h32: binom=3; 8'h33: binom=1;
      8'h41: binom=4; 8'h42: binom=6; 8'h43: binom=4; 8'h44: binom=1;
      8'h51: binom=5; 8'h52: binom=10; 8'h53: binom=10; 8'h54: binom=5; 8'h55: binom=1;
      8'h61: binom=6; 8'h62: binom=15; 8'h63: binom=20; 8'h64: binom=15; 8'h65: binom=6; 8'h66: binom=1;
      8'h71: binom=7; 8'h72: binom=21; 8'h73: binom=35; 8'h74: binom=35; 8'h75: binom=21; 8'h76: binom=7; 8'h77: binom=1;
      8'h81: binom=8; 8'h82: binom=28; 8'h83: binom=56; 8'h84: binom=70; 8'h85: binom=56; 8'h86: binom=28; 8'h87: binom=8; 8'h88: binom=1;
      default: binom=0;
    endcase
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
      done <= 0;
      result <= 0;
      for (int i=1; i<=8; i=i+1) begin
        bitmap[i] <= 0;
        duplicate[i] <= 0;
      end
    end
    else begin
      if (start && cycle_count == 0) begin
        {w[7], w[6], w[5], w[4], w[3], w[2], w[1], w[0]} <= weights;
        cycle_count <= 1;
        done <= 0;
        result <= 0;
        for (int i=1; i<=8; i=i+1) begin
          bitmap[i] <= 0;
          duplicate[i] <= 0;
        end
      end
      else if (cycle_count >= 1 && cycle_count <= 85) begin
        for (int j=0; j<3; j=j+1) begin
          automatic integer idx = (cycle_count-1)*3 + j;
          if (idx < 256) begin
            automatic reg [7:0] subset = idx;
            automatic reg [3:0] k = popcount(subset);
            automatic reg [7:0] sum_val = compute_sum(subset);
            if (k >=1 && k <=8 && k <= n) begin
              if (bitmap[k][sum_val]) duplicate[k] <= 1;
              else bitmap[k] <= bitmap[k] | (128'd1 << sum_val);
            end
          end
        end
        cycle_count <= cycle_count + 1;
      end
      else if (cycle_count > 85 && cycle_count < 100) begin
        cycle_count <= cycle_count + 1;
      end
      else if (cycle_count == 100) begin
        valid = 0;
        for (int k=1; k<=8; k=k+1) begin
          if (k > n) continue;
          if ($countones(bitmap[k]) == binom(n, k) && !duplicate[k]) 
            valid = valid > k ? valid : k;
        end
        result <= valid[3:0];
        done <= 1;
      end 
    end
  end
endmodule