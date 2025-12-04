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

  // 256-bit buffers for non-digit and digit characters
  reg [255:0] non_digits;
  reg [255:0] digits;

  // 6-bit counters for number of stored characters
  reg [5:0] non_dig_cnt;
  reg [5:0] dig_cnt;

  // FSM states
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Next-state logic
  always_comb begin
    next_state = state; // default
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (non_dig_cnt + dig_cnt == MAX_LEN) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Combinational result for the current concatenation of non-digits + digits
  function [255:0] concat_buffers;
    input [255:0] nd;
    input [255:0] dg;
    input [5:0] nd_cnt;
    input [5:0] dg_cnt;
    integer i;
    begin
      concat_buffers = 256'b0;
      // Place non-digits first
      for (i = 0; i < 256; i = i + 8) begin
        if (i/8 < nd_cnt) concat_buffers[i+:8] = nd[i+:8];
        else concat_buffers[i+:8] = 8'b0;
      end
      // Append digits
      for (i = 256; i < 512; i = i + 8) begin
        if ((i-256)/8 < dg_cnt) concat_buffers[i+:8] = dg[i+:8];
        else concat_buffers[i+:8] = 8'b0;
      end
    end
  endfunction

  // FSM outputs and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      non_digits <= 256'b0;
      digits     <= 256'b0;
      non_dig_cnt <= 6'b0;
      dig_cnt     <= 6'b0;
      done        <= 1'b0;
      valid_out   <= 1'b0;
      result      <= 256'b0;
    end else begin
      case (state)
        IDLE: begin
          // Clear on reset or when not processing
          non_digits <= 256'b0;
          digits     <= 256'b0;
          non_dig_cnt <= 6'b0;
          dig_cnt     <= 6'b0;
          done        <= 1'b0;
          valid_out   <= 1'b0;
          // result holds previous data (not cleared)
        end

        PROCESSING: begin
          // Extend current result during processing (optional but keeps output consistent)
          result <= concat_buffers(non_digits, digits, non_dig_cnt, dig_cnt);
          done <= 1'b0;
          valid_out <= 1'b0;

          if (valid_in) begin
            if ((char_in >= "0") && (char_in <= "9")) begin
              // Digit: store in digits buffer
              if (dig_cnt < MAX_LEN) begin
                digits[dig_cnt*8 +: 8] <= char_in;
                dig_cnt <= dig_cnt + 1;
              end
            end else begin
              // Non-digit: store in non_digits buffer
              if (non_dig_cnt < MAX_LEN) begin
                non_digits[non_dig_cnt*8 +: 8] <= char_in;
                non_dig_cnt <= non_dig_cnt + 1;
              end
            end
          end
        end

        DONE: begin
          // Final result: non-digits followed by digits
          result <= concat_buffers(non_digits, digits, non_dig_cnt, dig_cnt);
          done <= 1'b1;
          valid_out <= 1'b1; // 1 cycle
          // Counters and buffers remain as is until returning to IDLE
        end

        default: begin
          // No-op
        end
      endcase
    end
  end
endmodule
