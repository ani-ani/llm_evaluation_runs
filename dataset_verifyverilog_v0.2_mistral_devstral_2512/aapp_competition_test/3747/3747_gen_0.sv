module bulbasaur_counter (
  input clk,
  input rst_n,
  input start,
  input [127:0] str_input,
  input [7:0] str_len,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNTING,
    COMPUTING,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [3:0] char_index = 0;
  reg [7:0] count_B = 0;
  reg [7:0] count_u = 0;
  reg [7:0] count_l = 0;
  reg [7:0] count_b = 0;
  reg [7:0] count_a = 0;
  reg [7:0] count_s = 0;
  reg [7:0] count_r = 0;
  reg [3:0] cycle_count = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_index <= 0;
      count_B <= 0;
      count_u <= 0;
      count_l <= 0;
      count_b <= 0;
      count_a <= 0;
      count_s <= 0;
      count_r <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNTING;
            char_index <= 0;
            count_B <= 0;
            count_u <= 0;
            count_l <= 0;
            count_b <= 0;
            count_a <= 0;
            count_s <= 0;
            count_r <= 0;
            cycle_count <= 0;
            done <= 0;
          end
        end

        COUNTING: begin
          if (char_index < str_len) begin
            // Extract current character
            reg [7:0] current_char = str_input[(char_index + 1) * 8 - 1 : char_index * 8];

            // Count characters
            if (current_char == 8'h42) count_B <= count_B + 1;
            else if (current_char == 8'h75) count_u <= count_u + 1;
            else if (current_char == 8'h6C) count_l <= count_l + 1;
            else if (current_char == 8'h62) count_b <= count_b + 1;
            else if (current_char == 8'h61) count_a <= count_a + 1;
            else if (current_char == 8'h73) count_s <= count_s + 1;
            else if (current_char == 8'h72) count_r <= count_r + 1;

            char_index <= char_index + 1;
          end else begin
            state <= COMPUTING;
            cycle_count <= 0;
          end
        end

        COMPUTING: begin
          if (cycle_count < 19) begin
            cycle_count <= cycle_count + 1;
          end else begin
            // Compute result = min(B, u/2, l, b, a/2, s, r)
            reg [7:0] temp_result;
            temp_result = count_B;
            if (count_u / 2 < temp_result) temp_result = count_u / 2;
            if (count_l < temp_result) temp_result = count_l;
            if (count_b < temp_result) temp_result = count_b;
            if (count_a / 2 < temp_result) temp_result = count_a / 2;
            if (count_s < temp_result) temp_result = count_s;
            if (count_r < temp_result) temp_result = count_r;
            result <= temp_result;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule