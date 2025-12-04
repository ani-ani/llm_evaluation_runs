module integer_filter(
  input clk,
  input rst_n,
  input start,
  input [7:0][9:0] values,
  output reg [7:0][7:0] result,
  output reg [7:0] valid_mask,
  output reg done
);

  reg [3:0] idx;
  reg busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result     <= '0;
      valid_mask <= '0;
      done       <= 1'b0;
      idx        <= 4'd0;
      busy       <= 1'b0;
    end else begin
      if (!busy) begin
        if (start) begin
          // Initialize for new processing sequence
          result     <= '0;
          valid_mask <= '0;
          done       <= 1'b0;
          idx        <= 4'd0;
          busy       <= 1'b1;
        end
      end else begin
        // Busy: process one element per cycle
        // Extract type and value for current index
        // values[idx][9:8] = type, values[idx][7:0] = value
        if (values[idx][9:8] == 2'b01) begin
          result[idx]     <= values[idx][7:0];
          valid_mask[idx] <= 1'b1;
        end else begin
          result[idx]     <= result[idx];
          valid_mask[idx] <= valid_mask[idx];
        end

        if (idx == 4'd7) begin
          // Last element processed this cycle
          done <= 1'b1;
          busy <= 1'b0;
          idx  <= 4'd0;
        end else begin
          idx  <= idx + 4'd1;
        end
      end
    end
  end

endmodule