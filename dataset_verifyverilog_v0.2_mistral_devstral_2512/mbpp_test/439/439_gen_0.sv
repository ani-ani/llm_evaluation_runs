module multiple_to_single (
  input clk,
  input rst_n,
  input start,
  input [31:0] num_1, num_2, num_3, num_4, num_5, num_6,
  input [2:0] count,
  output reg [63:0] result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_SIGN,
    CONVERT_NUM,
    BUILD_RESULT,
    VERIFY,
    DONE
  } state_t;

  // Internal registers
  state_t state, next_state;
  reg [2:0] current_num_idx;
  reg [31:0] current_num;
  reg [63:0] temp_result;
  reg [63:0] digit_buffer;
  reg [5:0] digit_count;
  reg [5:0] digit_pos;
  reg [3:0] digit;
  reg [5:0] total_digits;
  reg is_negative;
  reg [5:0] max_digits;
  reg [5:0] shift_amount;
  reg [5:0] current_digit_idx;
  reg [5:0] num_digits;
  reg [5:0] num_digits_temp;
  reg [5:0] i, j;
  reg [31:0] abs_num;
  reg [31:0] div_temp;
  reg [31:0] mod_temp;
  reg [31:0] power_of_10;
  reg [5:0] digit_idx;
  reg [5:0] digit_idx_temp;
  reg [5:0] digit_idx_temp2;
  reg [5:0] digit_idx_temp3;
  reg [5:0] digit_idx_temp4;
  reg [5:0] digit_idx_temp5;
  reg [5:0] digit_idx_temp6;
  reg [5:0] digit_idx_temp7;
  reg [5:0] digit_idx_temp8;
  reg [5:0] digit_idx_temp9;
  reg [5:0] digit_idx_temp10;
  reg [5:0] digit_idx_temp11;
  reg [5:0] digit_idx_temp12;
  reg [5:0] digit_idx_temp13;
  reg [5:0] digit_idx_temp14;
  reg [5:0] digit_idx_temp15;
  reg [5:0] digit_idx_temp16;
  reg [5:0] digit_idx_temp17;
  reg [5:0] digit_idx_temp18;
  reg [5:0] digit_idx_temp19;
  reg [5:0] digit_idx_temp20;
  reg [5:0] digit_idx_temp21;
  reg [5:0] digit_idx_temp22;
  reg [5:0] digit_idx_temp23;
  reg [5:0] digit_idx_temp24;
  reg [5:0] digit_idx_temp25;
  reg [5:0] digit_idx_temp26;
  reg [5:0] digit_idx_temp27;
  reg [5:0] digit_idx_temp28;
  reg [5:0] digit_idx_temp29;
  reg [5:0] digit_idx_temp30;
  reg [5:0] digit_idx_temp31;
  reg [5:0] digit_idx_temp32;
  reg [5:0] digit_idx_temp33;
  reg [5:0] digit_idx_temp34;
  reg [5:0] digit_idx_temp35;
  reg [5:0] digit_idx_temp36;
  reg [5:0] digit_idx_temp37;
  reg [5:0] digit_idx_temp38;
  reg [5:0] digit_idx_temp39;
  reg [5:0] digit_idx_temp40;
  reg [5:0] digit_idx_temp41;
  reg [5:0] digit_idx_temp42;
  reg [5:0] digit_idx_temp43;
  reg [5:0] digit_idx_temp44;
  reg [5:0] digit_idx_temp45;
  reg [5:0] digit_idx_temp46;
  reg [5:0] digit_idx_temp47;
  reg [5:0] digit_idx_temp48;
  reg [5:0] digit_idx_temp49;
  reg [5:0] digit_idx_temp50;
  reg [5:0] digit_idx_temp51;
  reg [5:0] digit_idx_temp52;
  reg [5:0] digit_idx_temp53;
  reg [5:0] digit_idx_temp54;
  reg [5:0] digit_idx_temp55;
  reg [5:0] digit_idx_temp56;
  reg [5:0] digit_idx_temp57;
  reg [5:0] digit_idx_temp58;
  reg [5:0] digit_idx_temp59;
  reg [5:0] digit_idx_temp60;
  reg [5:0] digit_idx_temp61;
  reg [5:0] digit_idx_temp62;
  reg [5:0] digit_idx_temp63;
  reg [5:0] digit_idx_temp64;
  reg [5:0] digit_idx_temp65;
  reg [5:0] digit_idx_temp66;
  reg [5:0] digit_idx_temp67;
  reg [5:0] digit_idx_temp68;
  reg [5:0] digit_idx_temp69;
  reg [5:0] digit_idx_temp70;
  reg [5:0] digit_idx_temp71;
  reg [5:0] digit_idx_temp72;
  reg [5:0] digit_idx_temp73;
  reg [5:0] digit_idx_temp74;
  reg [5:0] digit_idx_temp75;
  reg [5:0] digit_idx_temp76;
  reg [5:0] digit_idx_temp77;
  reg [5:0] digit_idx_temp78;
  reg [5:0] digit_idx_temp79;
  reg [5:0] digit_idx_temp80;
  reg [5:0] digit_idx_temp81;
  reg [5:0] digit_idx_temp82;
  reg [5:0] digit_idx_temp83;
  reg [5:0] digit_idx_temp84;
  reg [5:0] digit_idx_temp85;
  reg [5:0] digit_idx_temp86;
  reg [5:0] digit_idx_temp87;
  reg [5:0] digit_idx_temp88;
  reg [5:0] digit_idx_temp89;
  reg [5:0] digit_idx_temp90;
  reg [5:0] digit_idx_temp91;
  reg [5:0] digit_idx_temp92;
  reg [5:0] digit_idx_temp93;
  reg [5:0] digit_idx_temp94;
  reg [5:0] digit_idx_temp95;
  reg [5:0] digit_idx_temp96;
  reg [5:0] digit_idx_temp97;
  reg [5:0] digit_idx_temp98;
  reg [5:0] digit_idx_temp99;
  reg [5:0] digit_idx_temp100;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      error <= 0;
      result <= 0;
      current_num_idx <= 0;
      temp_result <= 0;
      digit_buffer <= 0;
      digit_count <= 0;
      digit_pos <= 0;
      total_digits <= 0;
      is_negative <= 0;
      max_digits <= 0;
      shift_amount <= 0;
      current_digit_idx <= 0;
      num_digits <= 0;
      i <= 0;
      j <= 0;
      abs_num <= 0;
      div_temp <= 0;
      mod_temp <= 0;
      power_of_10 <= 0;
      digit_idx <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECK_SIGN;
      end
      CHECK_SIGN: begin
        next_state = CONVERT_NUM;
      end
      CONVERT_NUM: begin
        if (current_num_idx == count) next_state = BUILD_RESULT;
      end
      BUILD_RESULT: begin
        if (digit_pos == total_digits) next_state = VERIFY;
      end
      VERIFY: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          error <= 0;
          result <= 0;
          current_num_idx <= 0;
          temp_result <= 0;
          digit_buffer <= 0;
          digit_count <= 0;
          digit_pos <= 0;
          total_digits <= 0;
          is_negative <= 0;
          max_digits <= 0;
          shift_amount <= 0;
          current_digit_idx <= 0;
          num_digits <= 0;
          i <= 0;
          j <= 0;
          abs_num <= 0;
          div_temp <= 0;
          mod_temp <= 0;
          power_of_10 <= 0;
          digit_idx <= 0;
        end
        CHECK_SIGN: begin
          // Check if any input is negative
          is_negative <= (num_1[31] || num_2[31] || num_3[31] || num_4[31] || num_5[31] || num_6[31]);
          current_num_idx <= 0;
          total_digits <= 0;
          temp_result <= 0;
          digit_buffer <= 0;
          digit_count <= 0;
          digit_pos <= 0;
          max_digits <= 0;
          shift_amount <= 0;
          current_digit_idx <= 0;
          num_digits <= 0;
          i <= 0;
          j <= 0;
          abs_num <= 0;
          div_temp <= 0;
          mod_temp <= 0;
          power_of_10 <= 0;
          digit_idx <= 0;
        end
        CONVERT_NUM: begin
          // Select current number based on index
          case (current_num_idx)
            0: current_num <= num_1;
            1: current_num <= num_2;
            2: current_num <= num_3;
            3: current_num <= num_4;
            4: current_num <= num_5;
            5: current_num <= num_6;
            default: current_num <= 0;
          endcase

          // Convert current number to absolute value
          abs_num <= (current_num[31] ? ~current_num + 1 : current_num);

          // Count digits in current number
          num_digits <= 0;
          div_temp <= abs_num;
          while (div_temp > 0) begin
            div_temp <= div_temp / 10;
            num_digits <= num_digits + 1;
          end

          // Store digits in buffer
          div_temp <= abs_num;
          for (i = 0; i < num_digits; i = i + 1) begin
            mod_temp <= div_temp % 10;
            digit_buffer[(num_digits - 1 - i) * 4 +: 4] <= mod_temp;
            div_temp <= div_temp / 10;
          end

          // Update total digits
          total_digits <= total_digits + num_digits;

          // Move to next number
          current_num_idx <= current_num_idx + 1;
        end
        BUILD_RESULT: begin
          // Build result digit by digit
          digit <= digit_buffer[digit_pos * 4 +: 4];
          temp_result <= temp_result * 10 + digit;
          digit_pos <= digit_pos + 1;
        end
        VERIFY: begin
          // Check for overflow
          if (is_negative) begin
            if (temp_result > 64'h8000000000000000) begin
              error <= 1;
              result <= 64'h8000000000000000;
            end else begin
              result <= -temp_result;
            end
          end else begin
            if (temp_result > 64'h7FFFFFFFFFFFFFFF) begin
              error <= 1;
              result <= 64'h7FFFFFFFFFFFFFFF;
            end else begin
              result <= temp_result;
            end
          end
          done <= 1;
        end
        DONE: begin
          // Stay in DONE state until reset
        end
        default: begin
          // Default state handling
        end
      endcase
    end
  end

endmodule