module seven_counter(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [9:0] n,
  output reg [7:0] count,
  output reg done
);

  reg state;
  reg [9:0] i;
  reg [3:0] rem11, rem13;
  wire [3:0] thousands, hundreds, tens, units;
  wire [3:0] digit_count;
  
  localparam IDLE = 1'b0;
  localparam RUN = 1'b1;

  assign thousands = i / 4'd10;
  assign hundreds = (i % 10'd1000) / 7'd100;
  assign tens = (i % 7'd100) / 4'd10;
  assign units = i % 4'd10;
  
  assign digit_count = (thousands == 4'd7) + (hundreds == 4'd7) + (tens == 4'd7) + (units == 4'd7);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 8'd0;
      done <= 1'b0;
      i <= 10'd0;
      rem11 <= 4'd0;
      rem13 <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= RUN;
            i <= 10'd0;
            rem11 <= 4'd0;
            rem13 <= 4'd0;
            count <= 8'd0;
          end
        end
        
        RUN: begin
          if (i < n) begin
            if ((rem11 == 4'd0) || (rem13 == 4'd0)) begin
              count <= count + digit_count;
            end
            rem11 <= (rem11 == 4'd10) ? 4'd0 : rem11 + 4'd1;
            rem13 <= (rem13 == 4'd12) ? 4'd0 : rem13 + 4'd1;
            i <= i + 10'd1;
          end else begin
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule