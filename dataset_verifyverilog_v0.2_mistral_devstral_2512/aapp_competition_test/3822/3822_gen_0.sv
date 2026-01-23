module bus_excursion (
  input clk,
  input rst_n,
  input start,
  input [15:0] l,
  input [15:0] v1,
  input [15:0] v2,
  input [3:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  state_t state;
  reg [4:0] iter;
  reg [31:0] low, high, mid;
  reg [31:0] S, T;
  reg [31:0] T_v1, S_v2;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      iter <= 0;
      low <= 0;
      high <= l;
      mid <= 0;
      S <= 0;
      T <= 0;
      T_v1 <= 0;
      S_v2 <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATE;
            iter <= 0;
            low <= 0;
            high <= l;
            mid <= 0;
          end
        end
        CALCULATE: begin
          if (iter == 32) begin
            state <= DONE;
            // Final result calculation
            // result = (mid / v2) + ((l - mid) / v1)
            // Q32.32 = (Q16.16 / Q16.16) + (Q16.16 / Q16.16)
            // Each division is Q16.16 / Q16.16 = Q16.16, sum is Q16.16
            // To get Q32.32, multiply by 65536 (shift left 16)
            result <= ((mid << 16) / v2) + (((l - mid) << 16) / v1);
            done <= 1;
          end else begin
            // Binary search iteration
            mid <= (low + high) >> 1;
            S <= l - mid;
            // T = mid * (n * 2 - 1) - l
            // mid is Q16.16, (n*2-1) is integer, so multiply by 16.0 (shift left 16)
            T <= (mid * (n * 2 - 1)) - (l << 16);
            // T_v1 = T * v1 (Q32.16 * Q16.16 = Q48.32, but we only need Q32.32)
            // S_v2 = S * v2 (Q16.16 * Q16.16 = Q32.32)
            T_v1 <= T * v1;
            S_v2 <= S * v2;
            // Compare T_v1 and S_v2
            if (T_v1 > S_v2) begin
              high <= mid;
            end else begin
              low <= mid;
            end
            iter <= iter + 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule