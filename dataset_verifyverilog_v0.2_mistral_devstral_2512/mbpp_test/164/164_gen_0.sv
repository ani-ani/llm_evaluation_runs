module equivalent_divisors (
  input clk,
  input rst_n,
  input start,
  input [7:0] num1,
  input [7:0] num2,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC1,
    CALC2,
    COMPARE,
    DONE
  } state_t;

  state_t state;
  reg [7:0] sum1, sum2;
  reg [7:0] i1, i2;
  reg [7:0] sqrt1, sqrt2;
  reg [7:0] cycle_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum1 <= 0;
      sum2 <= 0;
      i1 <= 0;
      i2 <= 0;
      sqrt1 <= 0;
      sqrt2 <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC1;
            sum1 <= 1; // 1 is always a proper divisor
            sum2 <= 1;
            i1 <= 2;
            i2 <= 2;
            sqrt1 <= num1 >> 1; // Approximate sqrt
            sqrt2 <= num2 >> 1;
            cycle_count <= 0;
            done <= 0;
          end
        end

        CALC1: begin
          if (i1 <= sqrt1) begin
            if (num1 % i1 == 0) begin
              if (i1 == (num1 / i1)) begin
                sum1 <= sum1 + i1;
              end else begin
                sum1 <= sum1 + i1 + (num1 / i1);
              end
            end
            i1 <= i1 + 1;
            cycle_count <= cycle_count + 1;
          end else begin
            state <= CALC2;
          end
        end

        CALC2: begin
          if (i2 <= sqrt2) begin
            if (num2 % i2 == 0) begin
              if (i2 == (num2 / i2)) begin
                sum2 <= sum2 + i2;
              end else begin
                sum2 <= sum2 + i2 + (num2 / i2);
              end
            end
            i2 <= i2 + 1;
            cycle_count <= cycle_count + 1;
          end else begin
            state <= COMPARE;
          end
        end

        COMPARE: begin
          result <= (sum1 == sum2);
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule