module baron_munchausen (
  input clk,
  input rst_n,
  input start,
  input [3:0] a,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALCULATE,
    CHECK,
    NEXT,
    FOUND,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] n;
  reg [19:0] product;
  reg [4:0] sum_n, sum_an;
  reg [15:0] n_next;

  // Sum of digits function
  function [4:0] sum_digits;
    input [19:0] num;
    integer i;
    begin
      sum_digits = 0;
      for (i = 0; i < 20; i = i + 1) begin
        sum_digits = sum_digits + num[i*4 +: 4];
      end
    end
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n <= 0;
      result <= -1;
      done <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          n <= 0;
          result <= -1;
          done <= 0;
        end
        CALCULATE: begin
          product <= a * n;
          sum_n <= sum_digits(n);
          sum_an <= sum_digits(product);
        end
        CHECK: begin
          if (sum_an * a == sum_n) begin
            result <= n;
            done <= 1;
          end
        end
        NEXT: begin
          n <= n_next;
        end
        FOUND: begin
          result <= n;
          done <= 1;
        end
        DONE: begin
          result <= -1;
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALCULATE;
      end
      CALCULATE: next_state = CHECK;
      CHECK: begin
        if (sum_an * a == sum_n) next_state = FOUND;
        else next_state = NEXT;
      end
      NEXT: begin
        n_next = n + 1;
        if (n_next <= 9999) next_state = CALCULATE;
        else next_state = DONE;
      end
      FOUND: next_state = IDLE;
      DONE: next_state = IDLE;
    endcase
  end

endmodule