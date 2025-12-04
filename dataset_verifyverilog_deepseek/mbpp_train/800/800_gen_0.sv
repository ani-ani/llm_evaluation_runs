module space_remover (input clk, input rst_n, input start, input [7:0] data, input [3:0] len, output reg [127:0] result, output reg [4:0] out_len, output reg done);
  typedef enum {IDLE, PROCESSING} state_t;
  state_t state;
  reg [3:0] captured_len;
  reg [3:0] cnt;
  reg [3:0] pos;
  wire is_space;
  assign is_space = (data == 8'h20) || (data == 8'h0D) || (data == 8'h0A) || (data == 8'h09);
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      cnt <= 0;
      pos <= 0;
      result <= 0;
      out_len <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PROCESSING;
            cnt <= 0;
            pos <= 0;
            out_len <= 0;
            result <= 0;
            captured_len <= len;
          end
        end
        PROCESSING: begin
          if (!is_space) begin
            result[pos*8 +: 8] <= data;
            pos <= pos + 1;
            out_len <= out_len + 1;
          end
          if (cnt == captured_len - 1) begin
            state <= IDLE;
            done <= 1;
          end else begin
            cnt <= cnt + 1;
          end
        end
      endcase
    end
  end
endmodule