module fib4_calculator (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg [31:0] result,
  output reg done
);

typedef enum {IDLE, COMPUTING} state_t;
reg [31:0] a, b, c, d;
reg [15:0] counter;
state_t state;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1;
    result <= 0;
    a <= 0;
    b <= 0;
    c <= 0;
    d <= 0;
    counter <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1;
        if (start) begin
          if (n <= 3) begin
            case(n)
              0,1: result <= 0;
              2: result <= 2;
              3: result <= 0;
            endcase
          end else begin
            a <= 0;
            b <= 0;
            c <= 2;
            d <= 0;
            counter <= 0;
            done <= 0;
            state <= COMPUTING;
          end
        end
      end

      COMPUTING: begin
        if (counter == (n - 4)) begin
          result <= a + b + c + d;
          done <= 1;
          state <= IDLE;
        end else begin
          a <= b;
          b <= c;
          c <= d;
          d <= a + b + c + d;
          counter <= counter + 1;
        end
      end
    endcase
  end
end

endmodule