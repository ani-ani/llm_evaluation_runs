module first_repeated_char (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] char_count,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    READING,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] char_buffer [0:7]; // Buffer to store input characters
  reg [2:0] char_index; // Current character index
  reg [2:0] check_index; // Index for checking duplicates
  reg [2:0] check_against; // Index to compare against
  reg duplicate_found;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_index <= 0;
      check_index <= 0;
      check_against <= 0;
      duplicate_found <= 0;
      result <= 8'h00;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READING;
      end
      READING: begin
        if (char_index == char_count - 1) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (duplicate_found || (check_index == char_count - 1 && check_against == char_index)) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_index <= 0;
      check_index <= 0;
      check_against <= 0;
      duplicate_found <= 0;
      result <= 8'h00;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          // Reset internal signals
          char_index <= 0;
          check_index <= 0;
          check_against <= 0;
          duplicate_found <= 0;
          result <= 8'h00;
          done <= 0;
        end
        READING: begin
          // Store input character
          char_buffer[char_index] <= char_in;
          char_index <= char_index + 1;
        end
        PROCESSING: begin
          // Check for duplicates
          if (!duplicate_found) begin
            if (check_index < char_index) begin
              if (char_buffer[check_index] == char_buffer[char_index]) begin
                result <= char_buffer[check_index];
                duplicate_found <= 1;
              end
              check_index <= check_index + 1;
            end else begin
              check_index <= 0;
              check_against <= check_against + 1;
              if (check_against == char_index) begin
                char_index <= char_index + 1;
                check_against <= 0;
              end
            end
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule