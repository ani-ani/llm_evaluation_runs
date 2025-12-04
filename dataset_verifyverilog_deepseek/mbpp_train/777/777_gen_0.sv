module sum_non_repeated (
  input clk,
  input rst_n,
  input start,
  input [7:0] data [0:15],
  input [3:0] length,
  output reg [15:0] sum,
  output reg done
);

  reg [7:0] freq_table [0:255];
  reg [5:0] cycle;
  reg processing;
  reg [15:0] next_sum;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle <= 0;
      done <= 0;
      processing <= 0;
      sum <= 0;
      for (int i = 0; i < 256; i++) begin
        freq_table[i] <= 8'h0;
      end
    end else begin
      done <= 0;
      if (processing) begin
        if (cycle == 6'd20) begin
          processing <= 0;
          cycle <= 0;
          done <= 1;
          sum <= next_sum;
        end else begin
          cycle <= cycle + 1;
          if (cycle >= 6'd1 && cycle <= 6'd16) begin
            automatic int idx = cycle - 1;
            if (idx < length) begin
              freq_table[data[idx]] <= freq_table[data[idx]] + 1;
            end
          end
        end
      end else if (start) begin
        processing <= 1;
        cycle <= 0;
        sum <= 0;
        for (int i = 0; i < 256; i++) begin
          freq_table[i] <= 8'h0;
        end
      end
    end
  end

  always_comb begin
    next_sum = 16'h0;
    for (int i = 0; i < 256; i++) begin
      if (freq_table[i] == 8'd1) begin
        next_sum = next_sum + i;
      end
    end
  end

endmodule