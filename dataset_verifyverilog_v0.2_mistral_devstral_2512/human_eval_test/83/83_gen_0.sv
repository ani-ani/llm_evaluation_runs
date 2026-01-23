module starts_one_ends (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALC_10_POW,
    CALC_FINAL,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Lookup table for 10^(n-2) for n=1 to 6
  // Note: For n=1, we don't use this LUT (special case)
  // For n=2: 10^0 = 1
  // For n=3: 10^1 = 10
  // For n=4: 10^2 = 100
  // For n=5: 10^3 = 1000
  // For n=6: 10^4 = 10000
  reg [17:0] pow10_lut [0:5];

  // Intermediate result for 18 * 10^(n-2)
  reg [31:0] temp_result;

  // Initialize LUT
  always @* begin
    pow10_lut[0] = 1;    // n=2: 10^0
    pow10_lut[1] = 10;   // n=3: 10^1
    pow10_lut[2] = 100;  // n=4: 10^2
    pow10_lut[3] = 1000; // n=5: 10^3
    pow10_lut[4] = 10000; // n=6: 10^4
    pow10_lut[5] = 0;    // unused
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @* begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CALC_10_POW;
        else next_state = IDLE;
      end
      CALC_10_POW: next_state = CALC_FINAL;
      CALC_FINAL: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Datapath logic
  always @* begin
    case (current_state)
      IDLE: begin
        result = 0;
        done = 0;
      end
      CALC_10_POW: begin
        // Compute 18 * 10^(n-2) using shifts
        // 18 = 16 + 2, so 10^(n-2) * 18 = (10^(n-2) << 4) + (10^(n-2) << 1)
        if (n == 1) begin
          temp_result = 1;
        end else begin
          reg [17:0] pow10 = pow10_lut[n-2];
          temp_result = (pow10 << 4) + (pow10 << 1);
        end
      end
      CALC_FINAL: begin
        // For n=1, result is 1 (special case)
        // For n>=2, result is 18 * 10^(n-2)
        if (n == 1) begin
          result = 1;
        end else begin
          result = temp_result;
        end
        done = 0;
      end
      DONE: begin
        done = 1;
      end
    endcase
  end

endmodule