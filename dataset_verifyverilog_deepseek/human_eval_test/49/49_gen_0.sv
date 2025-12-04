module modp_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] p,
  output reg [15:0] result,
  output reg done
);

typedef enum {IDLE, COMP} state_t;
reg [15:0] captured_n;
reg [15:0] captured_p;
reg [15:0] current_result;
reg [3:0] cnt;
state_t state;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    result <= 0;
    current_result <= 0;
    cnt <= 0;
  end else begin
    done <= 0;
    case (state)
      IDLE: begin
        if (start) begin
          captured_n <= n;
          captured_p <= p;
          current_result <= 16'd1;
          cnt <= 15;
          state <= COMP;
        end
      end
      COMP: begin
        automatic logic [31:0] sq = current_result * current_result;
        automatic logic [15:0] temp1 = sq % captured_p;
        automatic logic [15:0] temp2 = captured_n[cnt] ? (temp1 * 2) % captured_p : temp1;
        current_result <= temp2;
        if (cnt == 0) begin
          result <= temp2;
          done <= 1;
          state <= IDLE;
        end else begin
          cnt <= cnt - 1;
        end
      end
    endcase
  end
end
endmodule