module game_winner (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  output reg [1:0] result,
  output reg valid,
  output reg done
);

  parameter MAX_LEN = 64;
  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;

  reg [1:0] state;
  reg [7:0] min_char;
  reg [5:0] char_count;
  reg [7:0] char_in_reg;
  reg [7:0] char_in_reg2;
  reg start_reg;
  reg start_reg2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_char <= 8'd127;
      char_count <= 0;
      char_in_reg <= 0;
      char_in_reg2 <= 0;
      start_reg <= 0;
      start_reg2 <= 0;
      result <= 2'b10;
      valid <= 0;
      done <= 0;
    end else begin
      // Pipeline registers
      char_in_reg <= char_in;
      char_in_reg2 <= char_in_reg;
      start_reg <= start;
      start_reg2 <= start_reg;

      case (state)
        IDLE: begin
          if (start_reg2) begin
            state <= PROCESSING;
            char_count <= 1;
            min_char <= char_in_reg2;
            result <= 2'b10;
            valid <= 0;
            done <= 0;
          end
        end

        PROCESSING: begin
          if (char_count == MAX_LEN - 1) begin
            state <= DONE;
          end

          if (char_in_reg2 > min_char) begin
            result <= 2'b01; // Ann wins
          end else begin
            result <= 2'b00; // Mike wins
          end

          valid <= 1;
          done <= 0;

          if (char_in_reg2 < min_char) begin
            min_char <= char_in_reg2;
          end

          char_count <= char_count + 1;
        end

        DONE: begin
          result <= 2'b10;
          valid <= 0;
          done <= 1;
          if (!start_reg2) begin
            state <= IDLE;
            char_count <= 0;
            min_char <= 8'd127;
          end
        end
      endcase
    end
  end

endmodule