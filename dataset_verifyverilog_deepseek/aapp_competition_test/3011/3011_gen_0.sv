module hill_number_detector(
  input clk,
  input rst_n,
  input start,
  input [9:0] num,
  output reg signed [15:0] result,
  output reg done
);

  reg [1:0] state, next_state;
  reg [1:0] main_counter;
  reg [1:0] invalid_counter;
  reg processing;
  reg start_reg;
  reg [3:0] digits [3:0];
  reg is_hill;
  reg [15:0] rom_out;
  reg [3:0] max_digit;
  reg [1:0] peak_pos;

  // States
  localparam IDLE = 2'd0;
  localparam SPLIT = 2'd1;
  localparam CHECK = 2'd2;
  localparam LOOKUP = 2'd3;
  localparam OUTPUT = 2'd4;
  localparam OUTPUT_INVALID = 2'd5;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      main_counter <= 0;
      invalid_counter <= 0;
      processing <= 0;
      start_reg <= 0;
      digits[3] <= 0;
      digits[2] <= 0;
      digits[1] <= 0;
      digits[0] <= 0;
      is_hill <= 0;
      rom_out <= 0;
    end else begin
      start_reg <= start;
      case (state)
        IDLE: begin
          done <= 0;
          if (start && !start_reg) begin
            digits[3] <= num / 1000;
            digits[2] <= (num % 1000) / 100;
            digits[1] <= (num % 100) / 10;
            digits[0] <= num % 10;
            state <= SPLIT;
            main_counter <= 0;
          end
        end

        SPLIT: begin
          main_counter <= main_counter + 1;
          state <= CHECK;
        end

        CHECK: begin
          max_digit = digits[3];
          peak_pos = 3;
          if (digits[2] >= max_digit) begin
            max_digit = digits[2];
            peak_pos = 2;
          end
          if (digits[1] >= max_digit) begin
            max_digit = digits[1];
            peak_pos = 1;
          end
          if (digits[0] >= max_digit) begin
            max_digit = digits[0];
            peak_pos = 0;
          end

          integer i;
          reg non_decr, non_incr;
          non_decr = 1;
          for (i = 3; i > peak_pos; i = i - 1) begin
            if (digits[i] > digits[i-1]) non_decr = 0;
          end

          non_incr = 1;
          for (i = peak_pos; i > 0; i = i - 1) begin
            if (digits[i] < digits[i-1]) non_incr = 0;
          end

          is_hill <= non_decr && non_incr;
          state <= LOOKUP;
        end

        LOOKUP: begin
          rom_out <= get_rom_val(num);
          state <= OUTPUT;
        end

        OUTPUT: begin
          done <= 1;
          if (is_hill) begin
            result <= rom_out;
            state <= IDLE;
          end else begin
            result <= -1;
            invalid_counter <= 3;
            state <= OUTPUT_INVALID;
          end
        end

        OUTPUT_INVALID: begin
          if (invalid_counter > 0) begin
            invalid_counter <= invalid_counter - 1;
          end else begin
            done <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

  function [15:0] get_rom_val(input [9:0] num);
    begin
      case (num)
        0: get_rom_val = 1;
        121: get_rom_val = 58;
        1221: get_rom_val = 123;
        default: get_rom_val = 0;
      endcase
    end
  endfunction

endmodule