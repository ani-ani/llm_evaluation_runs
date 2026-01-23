module first_non_repeating_char (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_array [7:0],
  output reg [7:0] result,
  output reg found,
  output reg done
);

  parameter CHAR_COUNT = 8;
  parameter IDLE = 3'b000;
  parameter COUNT_CHARS = 3'b001;
  parameter SEARCH_RESULT = 3'b010;
  parameter COMPLETE = 3'b100;

  reg [2:0] state;
  reg [3:0] count [7:0];
  reg [3:0] i;
  reg [3:0] j;
  reg [3:0] k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 8'b0;
      found <= 1'b0;
      done <= 1'b0;
      i <= 4'b0;
      j <= 4'b0;
      k <= 4'b0;
      for (int idx = 0; idx < CHAR_COUNT; idx = idx + 1) begin
        count[idx] <= 4'b0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNT_CHARS;
            i <= 4'b0;
            j <= 4'b0;
            k <= 4'b0;
            for (int idx = 0; idx < CHAR_COUNT; idx = idx + 1) begin
              count[idx] <= 4'b0;
            end
          end
        end

        COUNT_CHARS: begin
          if (i < CHAR_COUNT) begin
            if (j < CHAR_COUNT) begin
              if (char_array[i] == char_array[j]) begin
                count[i] <= count[i] + 1'b1;
              end
              j <= j + 1'b1;
            end else begin
              j <= 4'b0;
              i <= i + 1'b1;
            end
          end else begin
            state <= SEARCH_RESULT;
            i <= 4'b0;
          end
        end

        SEARCH_RESULT: begin
          if (i < CHAR_COUNT) begin
            if (count[i] == 1'b1) begin
              result <= char_array[i];
              found <= 1'b1;
              state <= COMPLETE;
            end else begin
              i <= i + 1'b1;
            end
          end else begin
            found <= 1'b0;
            result <= 8'b0;
            state <= COMPLETE;
          end
        end

        COMPLETE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule