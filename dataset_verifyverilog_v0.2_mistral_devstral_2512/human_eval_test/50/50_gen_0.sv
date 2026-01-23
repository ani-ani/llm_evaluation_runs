module caesar_decode(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input char_valid,
  input char_done,
  output reg [7:0] char_out,
  output reg char_out_valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] char_in_reg;
  reg char_valid_reg;
  reg char_done_reg;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_out <= 8'b0;
      char_out_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (char_done) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Input registration
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_in_reg <= 8'b0;
      char_valid_reg <= 1'b0;
      char_done_reg <= 1'b0;
    end else begin
      char_in_reg <= char_in;
      char_valid_reg <= char_valid;
      char_done_reg <= char_done;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_out <= 8'b0;
      char_out_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      char_out_valid <= 1'b0;
      done <= 1'b0;

      if (current_state == PROCESSING) begin
        if (char_valid_reg) begin
          // Process character
          if (char_in_reg >= 8'h61 && char_in_reg <= 8'h7A) begin
            // Lowercase letter: decode with Caesar cipher
            char_out <= ((((char_in_reg - 8'h61) + 21) % 26) + 8'h61);
          end else begin
            // Non-lowercase: pass through
            char_out <= char_in_reg;
          end
          char_out_valid <= 1'b1;
        end

        if (char_done_reg) begin
          done <= 1'b1;
        end
      end
    end
  end

endmodule