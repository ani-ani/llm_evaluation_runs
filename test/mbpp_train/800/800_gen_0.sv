module space_remover(
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] data,
  input  [3:0] len,
  output reg [127:0] result,
  output reg [4:0]   out_len,
  output reg         done
);

  reg        processing;
  reg [3:0] count;        // counts processed characters (0..15)
  reg [3:0] total_len;    // latched length

  wire is_ws;
  assign is_ws = (data == 8'h20) || // space
                 (data == 8'h0D) || // CR
                 (data == 8'h0A) || // LF
                 (data == 8'h09);   // TAB

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result     <= 128'b0;
      out_len    <= 5'd0;
      done       <= 1'b0;
      processing <= 1'b0;
      count      <= 4'd0;
      total_len  <= 4'd0;
    end else begin
      if (start && !processing) begin
        // Start a new operation
        processing <= 1'b1;
        done       <= 1'b0;
        result     <= 128'b0;
        out_len    <= 5'd0;
        count      <= 4'd0;
        total_len  <= len;
      end else if (processing) begin
        // Process incoming character
        if (!is_ws) begin
          // Shift existing result left by 8 and append new byte at LSB
          result  <= (result << 8) | {120'd0, data};
          out_len <= out_len + 5'd1;
        end

        // Increment processed character count
        count <= count + 4'd1;

        // Check for completion using next count value
        if (count + 4'd1 == total_len) begin
          done       <= 1'b1;
          processing <= 1'b0;
        end
      end else begin
        // Idle state
        done <= 1'b0;
      end
    end
  end

endmodule