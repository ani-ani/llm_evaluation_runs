module text_lowercase_underscore (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_index,
  input valid,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READING,
    VALIDATING,
    COMPLETE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] char_buffer [0:15];
  reg [3:0] char_count;
  reg underscore_found;
  reg underscore_pos_valid;
  reg [3:0] underscore_pos;
  reg [3:0] letter_count_before;
  reg [3:0] letter_count_after;
  reg [3:0] total_letters;
  reg [3:0] index;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_count <= 0;
      underscore_found <= 0;
      underscore_pos_valid <= 0;
      underscore_pos <= 0;
      letter_count_before <= 0;
      letter_count_after <= 0;
      total_letters <= 0;
      index <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // State-specific register updates
      case (current_state)
        IDLE: begin
          if (start) begin
            char_count <= 0;
            underscore_found <= 0;
            underscore_pos_valid <= 0;
            underscore_pos <= 0;
            letter_count_before <= 0;
            letter_count_after <= 0;
            total_letters <= 0;
            index <= 0;
            result <= 0;
            done <= 0;
          end
        end

        READING: begin
          if (valid) begin
            char_buffer[char_index] <= char_in;
            if (char_in == 8'h5f) begin // underscore
              if (!underscore_found) begin
                underscore_found <= 1;
                underscore_pos <= char_index;
                underscore_pos_valid <= (char_index != 0) && (char_index != 15);
              end
            end else if (char_in >= 8'h61 && char_in <= 8'h7a) begin // lowercase letter
              if (!underscore_found) begin
                letter_count_before <= letter_count_before + 1;
              end else begin
                letter_count_after <= letter_count_after + 1;
              end
              total_letters <= total_letters + 1;
            end

            if (char_index == 15) begin
              char_count <= 16;
            end
          end
        end

        VALIDATING: begin
          // Validation happens in one cycle
          result <= (char_count >= 2) &&
                   (char_count <= 16) &&
                   (underscore_found) &&
                   (underscore_pos_valid) &&
                   (letter_count_before >= 1) &&
                   (letter_count_after >= 1) &&
                   (total_letters == (char_count - 1));
        end

        COMPLETE: begin
          done <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = READING;
        end
      end

      READING: begin
        if (valid && char_index == 15) begin
          next_state = VALIDATING;
        end
      end

      VALIDATING: begin
        next_state = COMPLETE;
      end

      COMPLETE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule