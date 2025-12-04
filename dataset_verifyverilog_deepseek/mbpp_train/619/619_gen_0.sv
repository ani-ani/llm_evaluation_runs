module move_numbers (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  output reg [255:0] result,
  output reg done,
  output reg valid_out
);

parameter MAX_LEN = 32;

reg [255:0] non_digits, digits;
reg [5:0] non_dig_cnt, dig_cnt, char_cnt;
typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
state_t state;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    non_digits <= '0;
    digits <= '0;
    non_dig_cnt <= '0;
    dig_cnt <= '0;
    char_cnt <= '0;
    done <= '0;
    valid_out <= '0;
    result <= '0;
  end else begin
    done <= '0;
    valid_out <= '0;
    case (state)
      IDLE: begin
        if (start) begin
          non_digits <= '0;
          digits <= '0;
          non_dig_cnt <= '0;
          dig_cnt <= '0;
          char_cnt <= '0;
          state <= PROCESSING;
        end
      end
      
      PROCESSING: begin
        if (valid_in) begin
          if (char_in >= 8'h30 && char_in <= 8'h39) begin
            digits[dig_cnt*8 +:8] <= char_in;
            dig_cnt <= dig_cnt + 1;
          end else begin
            non_digits[non_dig_cnt*8 +:8] <= char_in;
            non_dig_cnt <= non_dig_cnt + 1;
          end
          char_cnt <= char_cnt + 1;
          if (char_cnt == MAX_LEN-1) state <= DONE;
        end
      end
      
      DONE: begin
        done <= '1;
        valid_out <= '1;
        for (int i=0; i<MAX_LEN; i++) begin
          if (i < non_dig_cnt) result[i*8 +:8] <= non_digits[i*8 +:8];
          else result[i*8 +:8] <= digits[(i-non_dig_cnt)*8 +:8];
        end
        state <= IDLE;
      end
    endcase
  end
end

endmodule