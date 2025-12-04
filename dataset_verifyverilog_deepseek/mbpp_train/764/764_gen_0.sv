module digit_counter (
  input clk,
  input rst_n,
  input start,
  input [127:0] str,
  output reg [4:0] count,
  output reg done
);

  reg busy;
  reg [3:0] index;
  reg start_prev;

  wire start_pulse = start && !start_prev;
  wire [7:0] current_byte = str[127 - index*8 -: 8];
  wire is_digit = (current_byte >= 8'h30) && (current_byte <= 8'h39);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_prev <= 0;
      count <= 0;
      done <= 0;
      busy <= 0;
      index <= 0;
    end else begin
      start_prev <= start;

      if (start_pulse) begin
        count <= 0;
        done <= 0;
        busy <= 1;
        index <= 0;
      end else if (busy) begin
        if (is_digit) begin
          count <= count + 1;
        end

        if (index == 15) begin
          busy <= 0;
          done <= 1;
        end else begin
          index <= index + 1;
        end
      end
    end
  end

endmodule