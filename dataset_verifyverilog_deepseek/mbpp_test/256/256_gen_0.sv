module count_primes (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] count,
  output reg done
);

localparam [2:0]
  IDLE     = 3'd0,
  CHECK_NUM = 3'd1,
  CHECK_DIV = 3'd2,
  UPDATE_COUNT = 3'd3,
  DONE     = 3'd4;

reg [2:0] state;
reg [7:0] current_num;
reg [7:0] divisor;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    count <= 8'b0;
    done <= 1'b0;
    current_num <= 8'd0;
    divisor <= 8'd0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          count <= 8'b0;
          current_num <= 8'd2;
          state <= CHECK_NUM;
        end else begin
          state <= IDLE;
        end
      end
      CHECK_NUM: begin
        done <= 1'b0;
        if (current_num < n) begin
          divisor <= 8'd2;
          state <= CHECK_DIV;
        end else begin
          state <= DONE;
        end
      end
      CHECK_DIV: begin
        done <= 1'b0;
        if (divisor <= ((current_num - 1) < 15 ? (current_num - 1) : 15)) begin
          if (current_num % divisor == 0) begin
            current_num <= current_num + 8'd1;
            state <= CHECK_NUM;
          end else begin
            divisor <= divisor + 8'd1;
            state <= CHECK_DIV;
          end
        end else begin
          state <= UPDATE_COUNT;
        end
      end
      UPDATE_COUNT: begin
        done <= 1'b0;
        count <= count + 8'd1;
        current_num <= current_num + 8'd1;
        state <= CHECK_NUM;
      end
      DONE: begin
        done <= 1'b1;
        state <= DONE;
      end
      default: state <= IDLE;
    endcase
  end
end

endmodule