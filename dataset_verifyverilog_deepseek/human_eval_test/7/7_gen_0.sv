module string_substring_filter (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_strings,
  input [511:0] strings_packed,
  input [23:0] substring,
  input [1:0] substring_len,
  output reg [7:0] match_mask,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    CHECK_STRING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] string_index, next_string_index;

  // Unpack current string
  wire [63:0] current_string = strings_packed[string_index*64 +:64];
  wire [7:0][7:0] string_bytes;
  assign string_bytes[0] = current_string[7:0];
  assign string_bytes[1] = current_string[15:8];
  assign string_bytes[2] = current_string[23:16];
  assign string_bytes[3] = current_string[31:24];
  assign string_bytes[4] = current_string[39:32];
  assign string_bytes[5] = current_string[47:40];
  assign string_bytes[6] = current_string[55:48];
  assign string_bytes[7] = current_string[63:56];

  // State and Index Updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      string_index <= 0;
      match_mask <= 8'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      string_index <= next_string_index;

      if (state == CHECK_STRING) begin
        if (string_index < num_strings) begin
          // Check substring for current string
          reg match;
          case (substring_len)
            2'b01: begin // 1 char
              match = (substring[7:0] == string_bytes[0]) ||
                      (substring[7:0] == string_bytes[1]) ||
                      (substring[7:0] == string_bytes[2]) ||
                      (substring[7:0] == string_bytes[3]) ||
                      (substring[7:0] == string_bytes[4]) ||
                      (substring[7:0] == string_bytes[5]) ||
                      (substring[7:0] == string_bytes[6]) ||
                      (substring[7:0] == string_bytes[7]);
            end
            2'b10: begin // 2 chars
              match = (({string_bytes[1], string_bytes[0]} == substring[15:0]) ||
                      ({string_bytes[2], string_bytes[1]} == substring[15:0]) ||
                      ({string_bytes[3], string_bytes[2]} == substring[15:0]) ||
                      ({string_bytes[4], string_bytes[3]} == substring[15:0]) ||
                      ({string_bytes[5], string_bytes[4]} == substring[15:0]) ||
                      ({string_bytes[6], string_bytes[5]} == substring[15:0]) ||
                      ({string_bytes[7], string_bytes[6]} == substring[15:0]));
            end
            2'b11: begin // 3 chars
              match = (({string_bytes[2], string_bytes[1], string_bytes[0]} == substring[23:0]) ||
                      ({string_bytes[3], string_bytes[2], string_bytes[1]} == substring[23:0]) ||
                      ({string_bytes[4], string_bytes[3], string_bytes[2]} == substring[23:0]) ||
                      ({string_bytes[5], string_bytes[4], string_bytes[3]} == substring[23:0]) ||
                      ({string_bytes[6], string_bytes[5], string_bytes[4]} == substring[23:0]) ||
                      ({string_bytes[7], string_bytes[6], string_bytes[5]} == substring[23:0]));
            end
            default: match = 1'b0;
          endcase
          match_mask[string_index] <= match;
        end
      end

      // Done handling
      if (next_state == DONE) done <= 1'b1;
      else if (state == DONE) done <= 1'b0;
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    next_string_index = string_index;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_STRING;
          next_string_index = 0;
        end
      end
      CHECK_STRING: begin
        if (string_index < 7) begin
          next_string_index = string_index + 1;
        end else begin
          next_state = DONE;
        end
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule