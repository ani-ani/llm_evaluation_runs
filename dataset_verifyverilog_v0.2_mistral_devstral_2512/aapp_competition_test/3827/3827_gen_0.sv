module string_validator(
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [2:0] idx,
  output reg result,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] READ = 2'b01;
  localparam [1:0] VALIDATE = 2'b10;
  localparam [1:0] DONE = 2'b11;

  // Internal registers
  reg [1:0] state;
  reg [3:0] cycle_counter;
  reg [3:0] count_a, count_b, count_c;
  reg [7:0] prev_char;
  reg [7:0] char_buffer [0:7];
  reg order_violation;
  reg [3:0] char_idx;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_counter <= 0;
      count_a <= 0;
      count_b <= 0;
      count_c <= 0;
      prev_char <= 0;
      order_violation <= 0;
      char_idx <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= READ;
            cycle_counter <= 0;
            count_a <= 0;
            count_b <= 0;
            count_c <= 0;
            prev_char <= 0;
            order_violation <= 0;
            char_idx <= 0;
            result <= 0;
            done <= 0;
          end
        end

        READ: begin
          if (cycle_counter < 8) begin
            // Store character in buffer
            char_buffer[char_idx] <= char_in;

            // Process character
            if (char_in == 8'h61) begin // 'a'
              if (prev_char > 8'h61 && prev_char != 0) begin
                order_violation <= 1;
              end
              count_a <= (count_a == 15) ? 15 : count_a + 1;
              prev_char <= 8'h61;
            end else if (char_in == 8'h62) begin // 'b'
              if (prev_char > 8'h62 && prev_char != 0) begin
                order_violation <= 1;
              end
              count_b <= (count_b == 15) ? 15 : count_b + 1;
              prev_char <= 8'h62;
            end else if (char_in == 8'h63) begin // 'c'
              if (prev_char > 8'h63 && prev_char != 0) begin
                order_violation <= 1;
              end
              count_c <= (count_c == 15) ? 15 : count_c + 1;
              prev_char <= 8'h63;
            end else if (char_in != 0) begin
              // Invalid character (not null, not a/b/c)
              order_violation <= 1;
            end

            cycle_counter <= cycle_counter + 1;
            char_idx <= char_idx + 1;
          end else begin
            state <= VALIDATE;
            cycle_counter <= 0;
          end
        end

        VALIDATE: begin
          if (cycle_counter < 4) begin
            cycle_counter <= cycle_counter + 1;
          end else begin
            // Validation complete
            if (order_violation || count_a == 0 || count_b == 0) begin
              result <= 0;
            end else if (count_c == count_a || count_c == count_b) begin
              result <= 1;
            end else begin
              result <= 0;
            end
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule