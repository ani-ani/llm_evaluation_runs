module cake_partition_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] m,
  input [15:0] r,
  input [15:0] candle_x[0:7],
  input [15:0] candle_y[0:7],
  input [7:0] cut_a[0:3],
  input [7:0] cut_b[0:3],
  input [15:0] cut_c[0:3],
  output reg result,
  output reg done
);

  reg [4:0] clk_cnt;
  reg has_duplicate;
  reg [3:0] signatures[0:7];
  reg [24:0] temp_sum[0:3];
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_cnt <= 0;
      done <= 0;
      result <= 0;
      has_duplicate <= 0;
      foreach (signatures[i]) signatures[i] <= 0;
      foreach (temp_sum[i]) temp_sum[i] <= 0;
    end else begin
      if (start && clk_cnt == 5'b0) begin
        clk_cnt <= 1;
        done <= 0;
        result <= 0;
        has_duplicate <= 0;
      end else if (clk_cnt != 0 && clk_cnt < 25) begin
        clk_cnt <= clk_cnt + 1;
      end
      
      done <= 0;
      result <= 0;

      // Calculation phase (cycles 1-16)
      if (clk_cnt >= 1 && clk_cnt <= 16) begin
        integer candle_index = (clk_cnt - 1) >> 1;
        if (candle_index < n) begin
          if ((clk_cnt - 1) % 2 == 0) begin
            // Cycle 1: compute a*x + b*y
            for (int k = 0; k < 4; k++) begin
              if (k < m) begin
                temp_sum[k] <= $signed(cut_a[k]) * $signed(candle_x[candle_index]) + $signed(cut_b[k]) * $signed(candle_y[candle_index]);
              end
            end
          end else begin
            // Cycle 2: compute total and store signature
            reg [3:0] sig;
            for (int k = 0; k < 4; k++) begin
              if (k < m) begin
                reg [29:0] c_ext = { {14{cut_c[k][15]}}, cut_c[k] };
                reg [29:0] sum_ext = { {5{temp_sum[k][24]}}, temp_sum[k] };
                reg [29:0] total = sum_ext + c_ext;
                sig[k] = ~total[29];
              end else begin
                sig[k] = 1'b0;
              end
            end
            signatures[candle_index] <= sig;
          end
        end
      end

      // Check phase (cycles 17-24)
      if (clk_cnt >= 17 && clk_cnt <= 24) begin
        integer check_index = clk_cnt - 17;
        if (check_index < n) begin
          reg [3:0] mask;
          case (m)
            2'd1: mask = 4'b0001;
            2'd2: mask = 4'b0011;
            2'd3: mask = 4'b0111;
            2'd4: mask = 4'b1111;
            default: mask = 4'b0000;
          endcase
          reg [3:0] sig_i = signatures[check_index] & mask;
          reg dup_current = 0;
          for (int j = check_index + 1; j < n; j++) begin
            reg [3:0] sig_j = signatures[j] & mask;
            if (sig_i == sig_j) dup_current = 1;
          end
          if (dup_current) has_duplicate <= 1;
        end
      end

      // Completion (cycle 25)
      if (clk_cnt == 25) begin
        done <= 1;
        result <= ~has_duplicate;
        clk_cnt <= 0;
      end
    end
  end

endmodule