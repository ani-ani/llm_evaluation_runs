module odd_even_sum (
  input        clk,
  input        rst_n,
  input        start,
  input [15:0] data,
  input [3:0]  index,
  input [3:0]  count,
  output reg [15:0] sum_result,
  output reg       done
);

  reg [15:0] sum_reg;
  reg [3:0]  count_latched;
  reg [3:0]  elem_count;
  reg        processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_reg       <= 16'd0;
      sum_result    <= 16'd0;
      done          <= 1'b0;
      count_latched <= 4'd0;
      elem_count    <= 4'd0;
      processing    <= 1'b0;
    end else begin
      done <= 1'b0;

      // Start of new computation
      if (start) begin
        sum_reg       <= 16'd0;
        count_latched <= (count > 4'd8) ? 4'd8 : count; // safety cap
        elem_count    <= 4'd0;
        processing    <= 1'b1;
      end else if (processing) begin
        // Process current element if within desired count
        if (elem_count < count_latched) begin
          if ((index[0] == 1'b0) && (data[0] == 1'b1)) begin
            sum_reg <= sum_reg + data;
          end
          elem_count <= elem_count + 4'd1;
        end else begin
          // Completed processing all elements
          sum_result <= sum_reg;
          done       <= 1'b1;
          processing <= 1'b0;
        end
      end
    end
  end

endmodule