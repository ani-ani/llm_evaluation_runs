module triangle_ways (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  input [7:0] l,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_TOTAL,
    CALC_INVALID_A,
    CALC_INVALID_B,
    CALC_INVALID_C,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [31:0] total_ways = 0;
  reg [31:0] invalid_ways = 0;
  reg [7:0] x = 0;
  reg [7:0] z = 0;
  reg [15:0] s = 0;
  reg [15:0] m = 0;
  reg [31:0] temp = 0;
  reg [31:0] counter = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_ways <= 0;
      invalid_ways <= 0;
      x <= 0;
      z <= 0;
      s <= 0;
      m <= 0;
      temp <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_TOTAL;
            counter <= 0;
          end
        end

        CALC_TOTAL: begin
          // Calculate total ways: (l+3)*(l+2)*(l+1)/6 in Q16.16
          temp <= (l + 3) * (l + 2);
          temp <= temp * (l + 1);
          total_ways <= temp / 6;
          state <= CALC_INVALID_A;
          z <= a;
          x <= 0;
        end

        CALC_INVALID_A: begin
          if (x == 0) begin
            s <= 2*z - a - b - c;
          end
          if (s + x >= 0) begin
            m <= (s + x < l - x) ? (s + x) : (l - x);
            temp <= (m + 1) * (m + 2);
            invalid_ways <= invalid_ways + (temp >> 1);
          end
          if (x == l) begin
            z <= b;
            x <= 0;
            state <= CALC_INVALID_B;
          end else begin
            x <= x + 1;
          end
        end

        CALC_INVALID_B: begin
          if (x == 0) begin
            s <= 2*z - a - b - c;
          end
          if (s + x >= 0) begin
            m <= (s + x < l - x) ? (s + x) : (l - x);
            temp <= (m + 1) * (m + 2);
            invalid_ways <= invalid_ways + (temp >> 1);
          end
          if (x == l) begin
            z <= c;
            x <= 0;
            state <= CALC_INVALID_C;
          end else begin
            x <= x + 1;
          end
        end

        CALC_INVALID_C: begin
          if (x == 0) begin
            s <= 2*z - a - b - c;
          end
          if (s + x >= 0) begin
            m <= (s + x < l - x) ? (s + x) : (l - x);
            temp <= (m + 1) * (m + 2);
            invalid_ways <= invalid_ways + (temp >> 1);
          end
          if (x == l) begin
            result <= total_ways - invalid_ways;
            state <= DONE;
          end else begin
            x <= x + 1;
          end
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