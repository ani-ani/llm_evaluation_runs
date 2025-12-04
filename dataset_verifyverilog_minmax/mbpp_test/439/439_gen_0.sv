module multi_int_concat(
  input clk,
  input rst_n,
  input start,
  input signed [7:0] nums [0:3],
  output reg [31:0] result,
  output reg done
);

  // State machine enum
  typedef enum logic [1:0] {
    IDLE          = 2'b00,
    PROCESS_NUM   = 2'b01,
    CONVERT_DIGITS= 2'b10,
    FINISH        = 2'b11
  } state_t;

  state_t state, next_state;
  reg [1:0] i_index; // index of current number (0-3)
  reg sign_negative; // sign of first number
  reg [8:0] mag; // magnitude of current number (0-128)
  reg [1:0] digit_cnt; // 1,2,3 digits
  reg [31:0] mul_factor; // 10,100,1000
  reg [31:0] result_next; // next result value

  // Combinational logic for next state
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESS_NUM;
      end
      PROCESS_NUM: begin
        next_state = CONVERT_DIGITS;
      end
      CONVERT_DIGITS: begin
        if (i_index == 2'b11) next_state = FINISH;
        else next_state = PROCESS_NUM;
      end
      FINISH: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic (state update and control)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      i_index <= 2'b00;
      sign_negative <= 1'b0;
      mag <= 9'd0;
      digit_cnt <= 2'b00;
      mul_factor <= 32'd0;
      result_next <= 32'd0;
    end else begin
      // Update state
      state <= next_state;

      // Reset signals on IDLE
      if (state == IDLE) begin
        done <= 1'b0;
      end

      // Start handling: capture sign of first number
      if (state == IDLE && start) begin
        sign_negative <= nums[0][7];
        i_index <= 2'b00;
        result <= 32'd0;
      end

      // PROCESS_NUM: compute magnitude and digit count
      if (state == PROCESS_NUM) begin
        // Compute absolute value (magnitude)
        if (nums[i_index][7]) begin
          // Negative number: two's complement magnitude
          mag <= {1'b0, ~nums[i_index][7:0]} + 9'b1;
        end else begin
          mag <= {1'b0, nums[i_index][7:0]};
        end

        // Determine digit count
        if (mag == 9'd0) digit_cnt <= 2'b01; // 1 digit
        else if (mag < 9'd10) digit_cnt <= 2'b01;
        else if (mag < 9'd100) digit_cnt <= 2'b10;
        else digit_cnt <= 2'b11;

        // Choose multiplication factor based on digit count
        case (digit_cnt)
          2'b01: mul_factor <= 32'd10;
          2'b10: mul_factor <= 32'd100;
          2'b11: mul_factor <= 32'd1000;
          default: mul_factor <= 32'd10;
        endcase
      end

      // CONVERT_DIGITS: update result
      if (state == CONVERT_DIGITS) begin
        result_next <= result * mul_factor + mag;
        result <= result_next;
        // Increment index for next number
        i_index <= i_index + 1;
      end

      // FINISH: apply sign and assert done
      if (state == FINISH) begin
        if (sign_negative) result <= -$signed(result);
        done <= 1'b1;
      end
    end
  end

endmodule