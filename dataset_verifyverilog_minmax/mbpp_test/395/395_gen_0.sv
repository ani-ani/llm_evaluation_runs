module first_non_repeat(
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [7:0] result,
  output reg done
);

typedef enum {IDLE, PASS1, PASS2} state_t;
state_t state;
reg [3:0] cycle_counter;
reg [7:0] string_reg [0:7];
reg [3:0] freq [0:255];
reg [7:0] result_reg;
reg result_valid;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    cycle_counter <= 0;
    for (int i = 0; i < 256; i++) begin
      freq[i] <= 0;
    end
    result_reg <= 0;
    result_valid <= 0;
    result <= 0;
    done <= 0;
  end
  else begin
    case (state)
      IDLE: begin
        if (start) begin
          for (int i = 0; i < 8; i++) begin
            string_reg[i] <= str[i];
          end
          state <= PASS1;
          cycle_counter <= 0;
        end
      end

      PASS1: begin
        if (cycle_counter < 8) begin
          freq[string_reg[cycle_counter]] <= freq[string_reg[cycle_counter]] + 1;
          cycle_counter <= cycle_counter + 1;
        end
        else begin
          state <= PASS2;
          cycle_counter <= 0;
          result_valid <= 0;
        end
      end

      PASS2: begin
        if (cycle_counter < 8) begin
          if (freq[string_reg[cycle_counter]] == 1 && !result_valid) begin
            result_reg <= string_reg[cycle_counter];
            result_valid <= 1;
          end
          cycle_counter <= cycle_counter + 1;
          if (cycle_counter == 7) begin
            result <= result_valid ? result_reg : 8'b0;
            done <= 1;
            state <= IDLE;
          end
        end
      end
    endcase
  end
end
endmodule