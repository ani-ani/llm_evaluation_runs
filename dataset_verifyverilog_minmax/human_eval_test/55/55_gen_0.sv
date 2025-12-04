module fibonacci (
  input clk,
  input rst_n,
  input [7:0] n,
  input start,
  output reg [15:0] result,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] curr_n, cnt;
  reg [15:0] fib_a, fib_b; // F(k-2), F(k-1)

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: next_state = (start && !done) ? RUN : IDLE;
      RUN:  next_state = (cnt == curr_n) ? DONE : RUN;
      DONE: next_state = (start && !done) ? RUN : DONE;
      default: next_state = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      result  <= 16'h0;
      cnt     <= 8'h0;
      curr_n  <= 8'h0;
      fib_a   <= 16'h0;
      fib_b   <= 16'h1;
    end else begin
      state <= next_state;
      case (next_state)
        IDLE: begin
          done   <= 1'b0;
          result <= 16'h0;
          cnt    <= 8'h0;
          curr_n <= 8'h0;
          fib_a  <= 16'h0;
          fib_b  <= 16'h1;
        end
        RUN: begin
          if (cnt == 8'h0) begin
            // First active cycle: snapshot n and produce base cases
            curr_n <= n;
            cnt    <= cnt + 1;
            if (n == 8'h0) begin
              result <= 16'h0; // Fib(0)
              fib_a  <= 16'h0;
              fib_b  <= 16'h1;
            end else begin
              result <= 16'h1; // Fib(1)
              fib_a  <= 16'h0;
              fib_b  <= 16'h1;
            end
          end else begin
            // Iterate: Fib(k) = Fib(k-1) + Fib(k-2)
            cnt    <= cnt + 1;
            fib_a  <= fib_b;
            fib_b  <= result;
            result <= fib_a + fib_b;
          end
          if (cnt == curr_n) begin
            done <= 1'b1; // Latency: result valid at cycle n+1 after start
          end
        end
        DONE: begin
          done <= 1'b1; // Hold result until next start
        end
      endcase
    end
  end

endmodule
