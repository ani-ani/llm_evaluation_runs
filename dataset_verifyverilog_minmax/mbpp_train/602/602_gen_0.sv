module first_repeated_char (
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [7:0] result,
  output reg found,
  output reg done
);

  reg [2:0] state_counter;
  reg found_one;
  reg [7:0] prev_chars [0:7];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 8'b0;
      found <= 1'b0;
      done <= 1'b0;
      state_counter <= 3'b0;
      found_one <= 1'b0;
      for (int i = 0; i < 8; i++) begin
        prev_chars[i] <= 8'b0;
      end
    end else begin
      if (start && state_counter == 3'b0) begin
        found_one <= 1'b0;
        found <= 1'b0;
        state_counter <= 3'b1;
        prev_chars[0] <= str[0];
        if (str[1] == str[0]) begin
          result <= str[1];
          found <= 1'b1;
          found_one <= 1'b1;
        end
        prev_chars[1] <= str[1];
      end else if (state_counter == 3'b1) begin
        if (!found_one) begin
          for (int j = 0; j < 2; j++) begin
            if (str[2] == prev_chars[j]) begin
              result <= str[2];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[2] <= str[2];
        state_counter <= 3'b10;
      end else if (state_counter == 3'b10) begin
        if (!found_one) begin
          for (int j = 0; j < 3; j++) begin
            if (str[3] == prev_chars[j]) begin
              result <= str[3];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[3] <= str[3];
        state_counter <= 3'b11;
      end else if (state_counter == 3'b11) begin
        if (!found_one) begin
          for (int j = 0; j < 4; j++) begin
            if (str[4] == prev_chars[j]) begin
              result <= str[4];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[4] <= str[4];
        state_counter <= 3'b100;
      end else if (state_counter == 3'b100) begin
        if (!found_one) begin
          for (int j = 0; j < 5; j++) begin
            if (str[5] == prev_chars[j]) begin
              result <= str[5];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[5] <= str[5];
        state_counter <= 3'b101;
      end else if (state_counter == 3'b101) begin
        if (!found_one) begin
          for (int j = 0; j < 6; j++) begin
            if (str[6] == prev_chars[j]) begin
              result <= str[6];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[6] <= str[6];
        state_counter <= 3'b110;
      end else if (state_counter == 3'b110) begin
        if (!found_one) begin
          for (int j = 0; j < 7; j++) begin
            if (str[7] == prev_chars[j]) begin
              result <= str[7];
              found <= 1'b1;
              found_one <= 1'b1;
            end
          end
        end
        prev_chars[7] <= str[7];
        state_counter <= 3'b111;
      end else if (state_counter == 3'b111) begin
        done <= 1'b1;
        state_counter <= 3'b0;
      end
    end
  end

endmodule