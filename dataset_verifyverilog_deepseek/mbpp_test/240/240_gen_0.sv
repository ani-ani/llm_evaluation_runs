module list_replacer (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] list1_in,
  input [7:0][7:0] list2_in,
  input [3:0] len1_in,
  input [3:0] len2_in,
  output logic [15:0][7:0] result_out,
  output logic [3:0] result_len_out,
  output logic done
);

  logic start_d;
  logic [3:0] len1_copy, len2_copy;
  logic [4:0] total_len_wide;
  logic [3:0] total_len;

  assign len1_copy = (len1_in > 8) ? 4'd7 : (len1_in - 1);
  assign len2_copy = (len2_in > 8) ? 4'd8 : len2_in;
  assign total_len_wide = len1_copy + len2_copy;
  assign total_len = (total_len_wide > 15) ? 15 : total_len_wide[3:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_out <= '0;
      result_len_out <= 0;
      done <= 0;
      start_d <= 0;
    end else begin
      done <= 0;
      start_d <= start;

      if (start) begin
        result_len_out <= total_len;
        for (int i = 0; i < len1_copy; i++) begin
          result_out[i] <= (i < 8) ? list1_in[i] : 8'h0;
        end
        for (int j = 0; j < len2_copy; j++) begin
          int idx = len1_copy + j;
          result_out[idx] <= (j < 8) ? list2_in[j] : 8'h0;
        end
        for (int k = total_len; k < 16; k++) begin
          result_out[k] <= 8'h0;
        end
      end

      if (start_d) begin
        done <= 1'b1;
      end
    end
  end

endmodule