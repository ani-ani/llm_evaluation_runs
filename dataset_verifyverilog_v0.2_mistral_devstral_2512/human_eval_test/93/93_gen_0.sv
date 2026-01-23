module message_encoder(
  input clk,
  input rst_n,
  input start,
  input [127:0] message_in,
  input [7:0] valid_length,
  output reg [127:0] message_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] char_index;
  reg [7:0] current_char;
  reg [7:0] encoded_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_index <= 0;
      message_out <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING && current_state == PROCESSING) begin
        char_index <= char_index + 1;
      end else if (next_state == IDLE) begin
        char_index <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (char_index == 15) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
    endcase
  end

  // Character processing logic
  always @(*) begin
    current_char = message_in[(char_index * 8) +: 8];
    encoded_char = current_char;

    // Check if character is a letter
    if ((current_char >= 8'h41 && current_char <= 8'h5A) || 
        (current_char >= 8'h61 && current_char <= 8'h7A)) begin
      // Swap case
      if (current_char >= 8'h41 && current_char <= 8'h5A) begin
        encoded_char = current_char + 8'h20; // Upper to lower
      end else begin
        encoded_char = current_char - 8'h20; // Lower to upper
      end

      // Check if vowel and replace
      case (encoded_char)
        8'h41, 8'h61: encoded_char = 8'h43; // A/a -> C
        8'h45, 8'h65: encoded_char = 8'h47; // E/e -> G
        8'h49, 8'h69: encoded_char = 8'h4B; // I/i -> K
        8'h4F, 8'h6F: encoded_char = 8'h51; // O/o -> Q
        8'h55, 8'h75: encoded_char = 8'h59; // U/u -> Y
        default: ; // Keep swapped case for consonants
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      message_out <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          message_out <= 0;
          done <= 0;
        end
        PROCESSING: begin
          message_out[(char_index * 8) +: 8] <= encoded_char;
          done <= 0;
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule