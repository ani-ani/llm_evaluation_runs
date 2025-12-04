module frequency_counter(input clk, input rst_n, input start, input [7:0] data_in [0:15], input [7:0] query_key, output reg [7:0] frequency_value, output reg done);
  reg [7:0] counts [0:255];
  reg [4:0] counter;
  reg processing;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0; i<256; i++) counts[i] <= 8'd0;
      processing <= 1'b0;
      counter <= 5'd0;
      done <= 1'b0;
    end else begin
      if (start && !processing) begin
        for (int i=0; i<256; i++) counts[i] <= 8'd0;
        processing <= 1'b1;
        counter <= 5'd0;
        done <= 1'b0;
      end else if (processing) begin
        counts[data_in[counter]] <= counts[data_in[counter]] + 8'd1;
        if (counter == 5'd15) begin
          processing <= 1'b0;
          done <= 1'b1;
          counter <= 5'd0;
        end else begin
          counter <= counter + 5'd1;
        end
      end
    end
  end

  always_comb begin
    frequency_value = counts[query_key];
  end

endmodule