module boredom_counter(input clk, rst_n, start, input [3:0] str_len, input [15:0][7:0] str_data, output reg [2:0] count, output reg done);
  reg [3:0] cycle_cnt;
  reg processing;
  reg next_start;
  reg sentence_start;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      cycle_cnt <= 4'd0;
      next_start <= 1'b0;
      sentence_start <= 1'b0;
      count <= 3'd0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      if (processing) begin
        if (cycle_cnt < 16) begin
          if (cycle_cnt < str_len) begin
            if (sentence_start && str_data[cycle_cnt] == 8'h49)
              count <= count + 1;
            if ((str_data[cycle_cnt] == 8'h2E) || (str_data[cycle_cnt] == 8'h3F) || (str_data[cycle_cnt] == 8'h21)) begin
              next_start <= (cycle_cnt + 1 < str_len) ? 1'b1 : 1'b0;
            end else begin
              next_start <= 1'b0;
            end
          end else begin
            next_start <= 1'b0;
          end
          sentence_start <= next_start;
          if (cycle_cnt == 15) begin
            done <= 1'b1;
            processing <= 1'b0;
          end else
            cycle_cnt <= cycle_cnt + 1;
        end
      end else if (start) begin
        processing <= 1'b1;
        cycle_cnt <= 4'd0;
        count <= 3'd0;
        sentence_start <= (str_len > 0) ? 1'b1 : 1'b0;
        next_start <= 1'b0;
      end
    end
  end
endmodule