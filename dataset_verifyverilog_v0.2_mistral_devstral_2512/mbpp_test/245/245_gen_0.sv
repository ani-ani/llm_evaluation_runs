module bitonic_max_sum (
  input clk,
  input rst_n,
  input start,
  input [2:0] array_len,
  input [7:0] array_data [0:7],
  output reg [15:0] max_sum_result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    CALC_MSIBS,
    CALC_MSDBS,
    CALC_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal arrays
  reg [15:0] msibs [0:7];
  reg [15:0] msdbs [0:7];
  reg [7:0] arr_reg [0:7];

  // Loop counters
  reg [2:0] i_counter;
  reg [2:0] j_counter;

  // Temporary variables
  reg [15:0] temp_max;
  reg [15:0] current_sum;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      max_sum_result <= 0;
      i_counter <= 0;
      j_counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALC_MSIBS;
          // Initialize arrays
          for (int i = 0; i < 8; i++) begin
            arr_reg[i] = array_data[i];
            msibs[i] = array_data[i];
            msdbs[i] = array_data[i];
          end
          i_counter = 0;
          j_counter = 0;
        end
      end

      CALC_MSIBS: begin
        if (i_counter < array_len) begin
          if (j_counter < i_counter) begin
            if (arr_reg[i_counter] > arr_reg[j_counter]) begin
              if (msibs[j_counter] + arr_reg[i_counter] > msibs[i_counter]) begin
                msibs[i_counter] = msibs[j_counter] + arr_reg[i_counter];
              end
            end
            j_counter = j_counter + 1;
          end else begin
            j_counter = 0;
            i_counter = i_counter + 1;
          end
        end else begin
          next_state = CALC_MSDBS;
          i_counter = array_len - 1;
          j_counter = array_len - 1;
        end
      end

      CALC_MSDBS: begin
        if (i_counter >= 0) begin
          if (j_counter > i_counter) begin
            if (arr_reg[i_counter] > arr_reg[j_counter]) begin
              if (msdbs[j_counter] + arr_reg[i_counter] > msdbs[i_counter]) begin
                msdbs[i_counter] = msdbs[j_counter] + arr_reg[i_counter];
              end
            end
            j_counter = j_counter - 1;
          end else begin
            j_counter = array_len - 1;
            i_counter = i_counter - 1;
          end
        end else begin
          next_state = CALC_RESULT;
          i_counter = 0;
          temp_max = 0;
        end
      end

      CALC_RESULT: begin
        if (i_counter < array_len) begin
          current_sum = msibs[i_counter] + msdbs[i_counter] - arr_reg[i_counter];
          if (current_sum > temp_max) begin
            temp_max = current_sum;
          end
          i_counter = i_counter + 1;
        end else begin
          next_state = DONE;
          max_sum_result = temp_max;
        end
      end

      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule