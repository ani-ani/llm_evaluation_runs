module cfg_substring_matcher(
  input clk,
  input rst_n,
  input start,
  input [263:0] rules,
  input [95:0] text_line,
  output reg [95:0] longest_substr,
  output reg valid,
  output reg done
);

  typedef struct packed {
    logic is_var;
    logic [5:0] value;
  } symbol_t;

  typedef struct packed {
    logic [4:0] head;
    logic [6:0] prod [0:3];
  } rule_t;

  rule_t [7:0] rule_array;
  logic [5:0] text_chars [0:15];

  // State parameters
  enum {
    IDLE,
    INIT,
    LOOP_SUBSTR,
    LOOP_POS,
    INIT_DERIV,
    DERIV_FIND_VAR,
    DERIV_TRY_RULE,
    DERIV_APPLY_RULE,
    CHECK_MATCH,
    DONE
  } state;

  reg [7:0] cycle_counter;
  reg [3:0] len_reg;
  reg [3:0] pos_reg;
  reg [3:0] step_count;
  reg [3:0] current_string_length;
  reg [3:0] var_index;
  reg [2:0] rule_index;
  reg [3:0] substr_idx;

  symbol_t current_string [0:15];
  logic match_found;
  logic deriv_failed;

  // Combinational handlers
  always_comb begin
    match_found = 0;
    if (current_string_length == len_reg) begin
      match_found = 1;
      for (int i=0; i<len_reg; i++) begin
        if (current_string[i].is_var || current_string[i].value != text_chars[pos_reg+i]) begin
          match_found = 0;
        end
      end
    end
  end

  always_comb begin
    deriv_failed = 1;
    if (current_string_length <= len_reg) begin
      for (int i=0; i<current_string_length; i++) begin
        if (current_string[i].is_var) deriv_failed = 0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      cycle_counter <= 0;
      longest_substr <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          valid <= 0;
          if (start) begin
            state <= INIT;
            cycle_counter <= 1;
          end
        end

        INIT: begin
          // Unpack rules and text
          for (int i=0; i<8; i++) begin
            rule_array[i].head = rules[33*i +:5];
            for (int j=0; j<4; j++) begin
              rule_array[i].prod[j] = rules[33*i + 5 + 7*j +:7];
            end
          end
          for (int i=0; i<16; i++) begin
            text_chars[i] = text_line[6*i +:6];
          end
          state <= LOOP_SUBSTR;
          len_reg <= 16;
          cycle_counter <= cycle_counter + 1;
        end

        LOOP_SUBSTR: begin
          pos_reg <= 0;
          if (len_reg == 0) begin
            state <= DONE;
          end else begin
            state <= LOOP_POS;
          end
          cycle_counter <= cycle_counter + 1;
        end

        LOOP_POS: begin
          if (pos_reg > 16 - len_reg) begin
            len_reg <= len_reg - 1;
            state <= LOOP_SUBSTR;
          end else begin
            state <= INIT_DERIV;
          end
          cycle_counter <= cycle_counter + 1;
        end

        INIT_DERIV: begin
          current_string_length <= 1;
          current_string[0].is_var <= 1;
          current_string[0].value <= rule_array[0].head;
          step_count <= 0;
          for (int i=1; i<16; i++) current_string[i].value <= 0;
          state <= DERIV_FIND_VAR;
          cycle_counter <= cycle_counter + 1;
        end

        DERIV_FIND_VAR: begin
          substr_idx <= 0;
          while (substr_idx < current_string_length) begin
            if (current_string[substr_idx].is_var) break;
            substr_idx <= substr_idx + 1;
          end
          if (substr_idx < current_string_length && current_string[substr_idx].is_var) begin
            var_index <= substr_idx;
            rule_index <= 0;
            state <= DERIV_TRY_RULE;
          end else begin
            state <= CHECK_MATCH;
          end
          cycle_counter <= cycle_counter + 1;
        end

        DERIV_TRY_RULE: begin
          if (rule_index < 8) begin
            if (rule_array[rule_index].head == current_string[var_index].value &&
                (current_string_length + 3) <= len_reg) begin
              state <= DERIV_APPLY_RULE;
            end else begin
              rule_index <= rule_index + 1;
            end
          end else begin
            state <= CHECK_MATCH;
          end
          cycle_counter <= cycle_counter + 1;
        end

        DERIV_APPLY_RULE: begin
          // Shift elements right after var_index
          for (int i=current_string_length+3-1; i>var_index+3; i--) begin
            current_string[i] <= current_string[i-3];
          end
          // Insert production
          for (int i=0; i<4; i++) begin
            current_string[var_index+i].is_var <= rule_array[rule_index].prod[i][6];
            current_string[var_index+i].value <= rule_array[rule_index].prod[i][5:0];
          end
          current_string_length <= current_string_length + 3;
          step_count <= step_count + 1;
          state <= DERIV_FIND_VAR;
          rule_index <= 0;
          cycle_counter <= cycle_counter + 1;
        end

        CHECK_MATCH: begin
          if (match_found) begin
            valid <= 1;
            for (int i=0; i<16; i++) begin
              if (i < len_reg) longest_substr[6*i +:6] <= text_chars[pos_reg+i];
              else longest_substr[6*i +:6] <= 0;
            end
            state <= DONE;
          end else if (step_count < 16 && !deriv_failed) begin
            state <= DERIV_FIND_VAR;
          end else begin
            pos_reg <= pos_reg + 1;
            state <= LOOP_POS;
          end
          cycle_counter <= cycle_counter + 1;
        end

        DONE: begin
          done <= 1;
          if (!start) state <= IDLE;
          cycle_counter <= 0;
        end

        default: state <= IDLE;
      endcase

      // Timeout after 255 cycles
      if (cycle_counter >= 255) state <= DONE;
    end
  end
endmodule