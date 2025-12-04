module sum_divisors (
  input clk,
  input rst_n,
  input start,
  input [7:0] num,
  output reg [9:0] sum,
  output reg done
);

  typedef enum {IDLE, COMPUTING, DONE} state_t;
  state_t current_state, next_state;
  reg [7:0] counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      sum <= 0;
      done <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;
      case(current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            if (num <= 1) begin
              sum <= 0;
              done <= 1;
              next_state <= DONE;
            end else begin
              sum <= 1;
              if (num > 2) begin
                counter <= 2;
                next_state <= COMPUTING;
              end else begin
                done <= 1;
                next_state <= DONE;
              end
            end
          end else begin
            next_state <= IDLE;
          end
        end

        COMPUTING: begin
          if (counter <= num - 1) begin
            if (num % counter == 0) sum <= sum + counter;
            counter <= counter + 1;
            next_state <= COMPUTING;
          end else begin
            done <= 1;
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 0;
          next_state <= IDLE;
        end
      endcase
    end
  end

endmodule