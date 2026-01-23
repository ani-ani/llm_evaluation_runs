module wildcard_match (
  input clk,
  input rst_n,
  input start,
  input [2:0] s_len,
  input [2:0] t_len,
  input [63:0] s_data,
  input [63:0] t_data,
  output reg match,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    FIND_WILDCARD,
    CHECK_PREFIX,
    CHECK_SUFFIX,
    VERIFY_LENGTH,
    DONE
  } state_t;

  state_t state;
  reg [2:0] wildcard_pos; // Position of wildcard in s_data (0-7), 8 if no wildcard
  reg [2:0] prefix_len;   // Length of prefix before wildcard
  reg [2:0] suffix_len;   // Length of suffix after wildcard
  reg [2:0] i;            // Counter for comparisons
  reg [2:0] j;            // Counter for suffix comparisons
  reg prefix_match;      // Prefix match result
  reg suffix_match;      // Suffix match result
  reg length_valid;      // Length check result

  // Character extraction helper
  function logic [7:0] get_char(input [63:0] data, input [2:0] pos);
    return data[63 - 8*pos : 56 - 8*pos];
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      match <= 0;
      done <= 0;
      wildcard_pos <= 0;
      prefix_len <= 0;
      suffix_len <= 0;
      i <= 0;
      j <= 0;
      prefix_match <= 0;
      suffix_match <= 0;
      length_valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= FIND_WILDCARD;
            wildcard_pos <= 8; // Initialize to no wildcard
            i <= 0;
          end
        end

        FIND_WILDCARD: begin
          if (i < s_len) begin
            if (get_char(s_data, i) == 8'h2A) begin
              wildcard_pos <= i;
            end
            i <= i + 1;
          end else begin
            if (wildcard_pos == 8) begin
              // No wildcard found
              prefix_len <= s_len;
              suffix_len <= 0;
              state <= CHECK_PREFIX;
              i <= 0;
            end else begin
              // Wildcard found
              prefix_len <= wildcard_pos;
              suffix_len <= s_len - wildcard_pos - 1;
              state <= CHECK_PREFIX;
              i <= 0;
            end
          end
        end

        CHECK_PREFIX: begin
          if (i < prefix_len) begin
            if (get_char(s_data, i) != get_char(t_data, i)) begin
              prefix_match <= 0;
            end else begin
              prefix_match <= 1;
            end
            i <= i + 1;
          end else begin
            if (prefix_len == 0) begin
              prefix_match <= 1;
            end
            if (suffix_len == 0) begin
              state <= VERIFY_LENGTH;
            end else begin
              state <= CHECK_SUFFIX;
              i <= 0;
              j <= t_len - suffix_len;
            end
          end
        end

        CHECK_SUFFIX: begin
          if (i < suffix_len) begin
            if (get_char(s_data, wildcard_pos + 1 + i) != get_char(t_data, j + i)) begin
              suffix_match <= 0;
            end else begin
              suffix_match <= 1;
            end
            i <= i + 1;
          end else begin
            if (suffix_len == 0) begin
              suffix_match <= 1;
            end
            state <= VERIFY_LENGTH;
          end
        end

        VERIFY_LENGTH: begin
          length_valid <= (prefix_len + suffix_len) <= t_len;
          state <= DONE;
        end

        DONE: begin
          match <= prefix_match && suffix_match && length_valid;
          done <= 1;
        end

        default: begin
          state <= IDLE;
          match <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule