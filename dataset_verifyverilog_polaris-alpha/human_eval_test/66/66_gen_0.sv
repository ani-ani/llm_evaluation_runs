module uppercase_sum(
  input  wire        clk,
  input  wire        rst_n,
  input  reg         start,
  input  reg  [127:0] s_string,
  output reg  [10:0] sum,
  output reg         done
);

  reg [3:0]  index;
  reg        busy;

  wire [7:0] current_byte;
  assign current_byte = s_string[index*8 +: 8];

  wire is_uppercase;
  assign is_uppercase = (current_byte >= 8'd65) && (current_byte <= 8'd90);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum   <= 11'd0;
      done  <= 1'b0;
      index <= 4'd0;
      busy  <= 1'b0;
    end else begin
      if (start && !busy) begin
        sum   <= 11'd0;
        done  <= 1'b0;
        index <= 4'd0;
        busy  <= 1'b1;
      end else if (busy) begin
        if (is_uppercase)
          sum <= sum + current_byte;

        if (index == 4'd15) begin
          done  <= 1'b1;
          busy  <= 1'b0;
        end

        index <= index + 4'd1;
      end else begin
        // Hold sum and done until next start
        done <= done;
        sum  <= sum;
      end
    end
  end

endmodule