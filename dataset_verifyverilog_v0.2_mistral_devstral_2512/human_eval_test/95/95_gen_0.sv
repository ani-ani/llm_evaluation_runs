module check_dict_case (
  input clk,
  input rst_n,
  input start,
  input [7:0] valid_entries,
  input [63:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_EMPTY,
    PROCESS_KEYS,
    VALIDATE_CASE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] current_case; // 0: unknown, 1: lower, 2: upper
  reg invalid_flag;
  reg [2:0] entry_counter; // 3 bits for 8 entries
  reg [2:0] char_counter; // 3 bits for 8 characters
  reg [63:0] current_key;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      current_case <= 0;
      invalid_flag <= 0;
      entry_counter <= 0;
      char_counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state and output logic
  always @(*) begin
    next_state = current_state;
    result = 0;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_EMPTY;
        end
      end

      CHECK_EMPTY: begin
        if (valid_entries == 0) begin
          next_state = DONE;
          result = 0;
          done = 1;
        end else begin
          next_state = PROCESS_KEYS;
          entry_counter = 0;
          char_counter = 0;
          current_case = 0;
          invalid_flag = 0;
        end
      end

      PROCESS_KEYS: begin
        // Select current key based on entry_counter
        case (entry_counter)
          3'd0: current_key = key_0;
          3'd1: current_key = key_1;
          3'd2: current_key = key_2;
          3'd3: current_key = key_3;
          3'd4: current_key = key_4;
          3'd5: current_key = key_5;
          3'd6: current_key = key_6;
          3'd7: current_key = key_7;
        endcase

        // Check if current entry is valid
        if (valid_entries[entry_counter]) begin
          // Process each character
          if (char_counter < 8) begin
            // Check current character
            reg [7:0] current_char = current_key[(char_counter+1)*8-1 : char_counter*8];

            // Check for null character (invalid)
            if (current_char == 8'h00) begin
              invalid_flag = 1;
            end
            // Check for lowercase
            else if (current_char >= 8'h61 && current_char <= 8'h7A) begin
              if (current_case == 0) begin
                current_case = 1; // First character is lowercase
              end else if (current_case != 1) begin
                invalid_flag = 1; // Mixed case
              end
            end
            // Check for uppercase
            else if (current_char >= 8'h41 && current_char <= 8'h5A) begin
              if (current_case == 0) begin
                current_case = 2; // First character is uppercase
              end else if (current_case != 2) begin
                invalid_flag = 1; // Mixed case
              end
            end
            // Invalid character
            else begin
              invalid_flag = 1;
            end

            char_counter = char_counter + 1;
          end else begin
            // Move to next entry
            char_counter = 0;
            entry_counter = entry_counter + 1;
            
            // Check if all entries processed
            if (entry_counter == 8) begin
              next_state = VALIDATE_CASE;
            end
          end
        end else begin
          // Skip invalid entry
          char_counter = 0;
          entry_counter = entry_counter + 1;
          
          // Check if all entries processed
          if (entry_counter == 8) begin
            next_state = VALIDATE_CASE;
          end
        end
      end

      VALIDATE_CASE: begin
        if (!invalid_flag && current_case != 0) begin
          result = 1;
        end else begin
          result = 0;
        end
        next_state = DONE;
        done = 1;
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule