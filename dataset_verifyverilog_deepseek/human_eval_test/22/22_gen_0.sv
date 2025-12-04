module integer_filter ( input clk,
  input rst_n,
  input start,
  input [7:0][9:0] values,
  output reg [7:0][7:0] result,
  output reg [7:0] valid_mask,
  output reg done );

  reg [2:0] count;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      count <= 3'b0;
      processing <= 1'b0;
      done <= 1'b0;
      result <= {8{8'b0}};
      valid_mask <= 8'b0;
    end else begin
      if (start) begin
        processing <= 1'b1;
        count <= 3'b0;
      end else if (processing) begin
        if (count == 3'd7)
          processing <= 1'b0;
        count <= count + 1;
      end

      done <= (processing && (count == 3'd7));

      if (processing) begin
        if (values[count][9:8] == 2'b01) begin
          result[count] <= values[count][7:0];
          valid_mask[count] <= 1'b1;
        end else begin
          result[count] <= 8'b0;
          valid_mask[count] <= 1'b0;
        end
      end
    end
  end

endmodule