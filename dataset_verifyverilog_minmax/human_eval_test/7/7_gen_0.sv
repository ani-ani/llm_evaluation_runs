module string_substring_filter (
  input clk,
  input rst_n,
  input start,
  input reg [2:0] num_strings,
  input reg [511:0] strings_packed,
  input reg [23:0] substring,
  input reg [1:0] substring_len,
  output reg [7:0] match_mask,
  output reg done
);

  // FSM states
  localparam IDLE = 2'b00;
  localparam CHECK_STRING = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [2:0] idx, next_idx;
  reg [7:0] next_match_mask;
  reg next_done;

  // Current string byte (LSB-first within each 64-bit string)
  reg [7:0] str_byte [0:7];
  integer j;

  // Unpack current string into bytes (LSB is first char)
  always @(*) begin
    for (j = 0; j < 8; j = j + 1) begin
      str_byte[j] = strings_packed[8*idx +: 8];
    end
  end

  // FSM sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 3'b0;
      match_mask <= 8'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      idx <= next_idx;
      match_mask <= next_match_mask;
      done <= next_done;
    end
  end

  // FSM next-state logic and per-cycle operations
  always @(*) begin
    // Defaults
    next_state = state;
    next_idx = idx;
    next_match_mask = match_mask;
    next_done = 1'b0;

    case (state)
      IDLE: begin
        next_match_mask = 8'b0;
        next_done = 1'b0;
        if (start) begin
          next_idx = 3'b0;
          next_state = CHECK_STRING;
        end
      end

      CHECK_STRING: begin
        // Shift left and insert new bit at LSB
        next_match_mask = {match_mask[6:0], 1'b0};

        // Within-range check
        if (idx < num_strings) begin
          // Search for consecutive match in the 8-char string
          if (substring_len == 2'b01) begin
            // 1 char substring
            next_match_mask[0] = 1'b0;
            for (j = 0; j < 8; j = j + 1) begin
              if (str_byte[j] == substring[7:0]) next_match_mask[0] = 1'b1;
            end
          end else if (substring_len == 2'b10) begin
            // 2 char substring
            next_match_mask[0] = 1'b0;
            for (j = 0; j < 7; j = j + 1) begin
              if (str_byte[j] == substring[7:0] && str_byte[j+1] == substring[15:8]) next_match_mask[0] = 1'b1;
            end
          end else begin
            // 3 char substring (11)
            next_match_mask[0] = 1'b0;
            for (j = 0; j < 6; j = j + 1) begin
              if (str_byte[j] == substring[7:0] &&
                  str_byte[j+1] == substring[15:8] &&
                  str_byte[j+2] == substring[23:16]) next_match_mask[0] = 1'b1;
            end
          end
        end

        next_idx = idx + 1;
        if (idx == 3'd7) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // Hold outputs stable for 1 cycle; go back to IDLE
        next_match_mask = match_mask;
        next_done = 1'b1;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
        next_idx = 3'b0;
        next_match_mask = 8'b0;
        next_done = 1'b0;
      end
    endcase
  end

endmodule
