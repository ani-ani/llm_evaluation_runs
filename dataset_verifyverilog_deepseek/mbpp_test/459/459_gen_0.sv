module remove_uppercase (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_in,
  output reg [127:0] str_out,
  output reg [4:0] out_length,
  output reg done
);

  reg [4:0] cnt;
  reg [4:0] wr_idx;
  reg [127:0] str_out_temp;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      str_out <= 128'b0;
      out_length <= 5'b0;
      done <= 1'b0;
      processing <= 1'b0;
      cnt <= 5'b0;
      wr_idx <= 5'b0;
      str_out_temp <= 128'b0;
    end else begin
      done <= 1'b0;

      if (start && !processing) begin
        processing <= 1'b1;
        cnt <= 5'b0;
        wr_idx <= 5'b0;
        str_out_temp <= 128'b0;
      end else if (processing) begin
        automatic logic [7:0] current_char = str_in[cnt*8 +: 8];
        automatic logic is_upper = (current_char >= 8'h41 && current_char <= 8'h5A);

        if (!is_upper) begin
          str_out_temp[wr_idx*8 +: 8] = current_char;
          wr_idx = wr_idx + 1;
        end

        cnt = cnt + 1;

        if (cnt == 16) begin
          str_out <= str_out_temp;
          out_length <= wr_idx;
          done <= 1'b1;
          processing <= 1'b0;
        end
      end
    end
  end
endmodule