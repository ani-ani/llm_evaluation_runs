module string_prefixer(input clk, input rst_n, input start, input [63:0] str, input [2:0] len, output reg [63:0] prefix, output reg [2:0] plen, output reg ready, output reg done);
  reg [63:0] captured_str;
  reg [2:0] captured_len;
  reg [2:0] current_len;
  reg processing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      captured_str <= 64'h0;
      captured_len <= 3'h0;
      current_len <= 3'h0;
      processing <= 1'b0;
      prefix <= 64'h0;
      plen <= 3'h0;
      ready <= 1'b0;
      done <= 1'b0;
    end else begin
      ready <= 1'b0;
      done <= 1'b0;

      if (start) begin
        captured_str <= str;
        captured_len <= len;
        processing <= (len != 3'h0);
        current_len <= 3'h0;
        if (len == 3'h0) done <= 1'b1;
      end else if (processing) begin
        if (current_len < captured_len) begin
          current_len <= current_len + 1;
          plen <= current_len + 1;
          ready <= 1'b1;
          if ((current_len + 1) == captured_len) begin
            done <= 1'b1;
            processing <= 1'b0;
          end
        end else begin
          processing <= 1'b0;
        end
      end

      if (ready) begin
        prefix[63:56] <= (plen >= 1) ? captured_str[63:56] : 8'b0;
        prefix[55:48] <= (plen >= 2) ? captured_str[55:48] : 8'b0;
        prefix[47:40] <= (plen >= 3) ? captured_str[47:40] : 8'b0;
        prefix[39:32] <= (plen >= 4) ? captured_str[39:32] : 8'b0;
        prefix[31:24] <= (plen >= 5) ? captured_str[31:24] : 8'b0;
        prefix[23:16] <= (plen >= 6) ? captured_str[23:16] : 8'b0;
        prefix[15:8] <= (plen >= 7) ? captured_str[15:8] : 8'b0;
        prefix[7:0] <= 8'b0;
      end else begin
        prefix <= 64'b0;
      end
    end
  end
endmodule