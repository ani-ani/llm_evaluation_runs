module space_remover (
  input clk,
  input rst_n,
  input start,
  input [7:0] data,
  input [3:0] len,
  output reg [127:0] result,
  output reg [4:0] out_len,
  output reg done
);

  reg [4:0] count;      // how many input chars consumed (0..len)
  reg [4:0] out_len_r;  // running count of non-space chars output
  reg busy;             // processing in progress
  wire is_ws;

  // Whitespace (0x20 space, 0x0D CR, 0x0A LF, 0x09 TAB)
  assign is_ws = (data == 8'h20) || (data == 8'h0D) || (data == 8'h0A) || (data == 8'h09);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result   <= 128'b0;
      out_len  <= 5'b0;
      done     <= 1'b0;
      count    <= 5'b0;
      out_len_r<= 5'b0;
      busy     <= 1'b0;
    end else begin
      if (!busy) begin
        // Idle: wait for start
        done     <= 1'b0;
        out_len  <= 5'b0;
        result   <= 128'b0;
        count    <= 5'b0;
        out_len_r<= 5'b0;
        if (start) begin
          busy   <= 1'b1;
        end
      end else begin
        // Busy: consume exactly len characters
        count <= count + 1;
        if (!is_ws) begin
          // Pack next byte at the contiguous location for this output position
          result[(out_len_r * 8) +: 8] <= data;
          out_len_r <= out_len_r + 1;
        end
        if (count == len) begin
          // Completed
          busy     <= 1'b0;
          done     <= 1'b1;
          out_len  <= out_len_r;
          count    <= 5'b0;
          out_len_r<= 5'b0;
        end else begin
          done     <= 1'b0;
        end
      end
    end
  end
endmodule
