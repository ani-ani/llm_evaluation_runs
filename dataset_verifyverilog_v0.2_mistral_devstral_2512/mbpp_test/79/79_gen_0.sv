module word_len_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input char_valid,
  input char_last,
  output reg result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] READING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  // Registers
  reg [1:0] state;
  reg [4:0] current_length;
  reg result_reg;
  reg [4:0] char_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_length <= 0;
      result_reg <= 0;
      char_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READING;
            current_length <= 0;
            result_reg <= 0;
            char_count <= 0;
            result <= 0;
            done <= 0;
          end
        end
        READING: begin
          if (char_valid) begin
            char_count <= char_count + 1;
            if (char_in == 8'h20) begin
              // Space character
              if (current_length[0] == 1) begin
                result_reg <= 1;
              end
              current_length <= 0;
            end else begin
              // Non-space character
              if (current_length < 15) begin
                current_length <= current_length + 1;
              end
              // If current_length is 15, it stays at 15 (saturate)
            end
            // Check if this is the last character
            if (char_last) begin
              if (current_length[0] == 1) begin
                result_reg <= 1;
              end
              state <= DONE;
            end
          end else if (char_last) begin
            // Handle case where char_valid is low but char_last is high
            if (current_length[0] == 1) begin
              result_reg <= 1;
            end
            state <= DONE;
          end
        end
        DONE: begin
          result <= result_reg;
          done <= 1;
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule