module string_rearrange (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] char_array,
  output reg [7:0][7:0] result,
  output reg valid,
  output reg no_solution,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    SORT,
    CHECK,
    MODIFY,
    VERIFY,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0][7:0] sorted_array;
  reg [7:0][7:0] modified_array;
  reg [7:0][7:0] temp_array;
  reg [7:0][7:0] substrings [0:4];
  reg [3:0] sort_pass;
  reg [3:0] sort_i;
  reg [3:0] check_i;
  reg [3:0] verify_i;
  reg [3:0] substring_i;
  reg [3:0] shift_count;
  reg duplicate_found;
  reg all_same;
  reg [3:0] modify_attempt;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      valid <= 0;
      no_solution <= 0;
      done <= 0;
      sort_pass <= 0;
      sort_i <= 0;
      check_i <= 0;
      verify_i <= 0;
      substring_i <= 0;
      shift_count <= 0;
      duplicate_found <= 0;
      all_same <= 0;
      modify_attempt <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = SORT;
      end
      SORT: begin
        if (sort_pass == 7 && sort_i == 7) next_state = CHECK;
      end
      CHECK: begin
        if (check_i == 4 && substring_i == 4) begin
          if (duplicate_found) next_state = MODIFY;
          else next_state = DONE;
        end
      end
      MODIFY: begin
        if (modify_attempt == 2) next_state = DONE;
        else if (modify_attempt == 0 && shift_count == 7) next_state = VERIFY;
        else if (modify_attempt == 1) next_state = VERIFY;
      end
      VERIFY: begin
        if (verify_i == 4 && substring_i == 4) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = SORT;
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sorted_array <= '0;
      modified_array <= '0;
      temp_array <= '0;
      result <= '0;
    end else begin
      case (current_state)
        IDLE: begin
          valid <= 0;
          no_solution <= 0;
          done <= 0;
        end
        SORT: begin
          // Bubble sort implementation
          if (sort_pass < 7) begin
            if (sort_i < 7 - sort_pass) begin
              if (char_array[sort_i] > char_array[sort_i + 1]) begin
                temp_array[sort_i] <= char_array[sort_i + 1];
                temp_array[sort_i + 1] <= char_array[sort_i];
              end else begin
                temp_array[sort_i] <= char_array[sort_i];
                temp_array[sort_i + 1] <= char_array[sort_i + 1];
              end
              sort_i <= sort_i + 1;
            end else begin
              sort_i <= 0;
              sort_pass <= sort_pass + 1;
            end
          end else begin
            // Copy sorted array
            sorted_array <= temp_array;
          end
        end
        CHECK: begin
          // Generate substrings and check for duplicates
          if (substring_i < 5) begin
            if (check_i < 4) begin
              substrings[substring_i][check_i] <= sorted_array[substring_i + check_i];
              check_i <= check_i + 1;
            end else begin
              check_i <= 0;
              substring_i <= substring_i + 1;
            end
          end else begin
            // Check for duplicates
            duplicate_found <= 0;
            for (int i = 0; i < 5; i = i + 1) begin
              for (int j = i + 1; j < 5; j = j + 1) begin
                if (substrings[i] == substrings[j]) begin
                  duplicate_found <= 1;
                end
              end
            end
            // Check if all characters are same
            all_same <= 1;
            for (int i = 0; i < 7; i = i + 1) begin
              if (sorted_array[i] != sorted_array[i + 1]) begin
                all_same <= 0;
              end
            end
          end
        end
        MODIFY: begin
          if (modify_attempt == 0) begin
            // Cyclic shift
            if (shift_count < 7) begin
              modified_array[0] <= sorted_array[shift_count + 1];
              for (int i = 1; i < 8; i = i + 1) begin
                if (i <= shift_count) begin
                  modified_array[i] <= sorted_array[i - 1];
                end else begin
                  modified_array[i] <= sorted_array[i];
                end
              end
              shift_count <= shift_count + 1;
            end
          end else begin
            // Reverse
            for (int i = 0; i < 8; i = i + 1) begin
              modified_array[i] <= sorted_array[7 - i];
            end
            modify_attempt <= modify_attempt + 1;
          end
        end
        VERIFY: begin
          // Generate substrings from modified array and check
          if (substring_i < 5) begin
            if (verify_i < 4) begin
              substrings[substring_i][verify_i] <= modified_array[substring_i + verify_i];
              verify_i <= verify_i + 1;
            end else begin
              verify_i <= 0;
              substring_i <= substring_i + 1;
            end
          end else begin
            // Check for duplicates
            duplicate_found <= 0;
            for (int i = 0; i < 5; i = i + 1) begin
              for (int j = i + 1; j < 5; j = j + 1) begin
                if (substrings[i] == substrings[j]) begin
                  duplicate_found <= 1;
                end
              end
            end
            if (duplicate_found) begin
              modify_attempt <= modify_attempt + 1;
              substring_i <= 0;
              verify_i <= 0;
            end
          end
        end
        DONE: begin
          if (all_same) begin
            no_solution <= 1;
            valid <= 0;
          end else if (duplicate_found) begin
            no_solution <= 1;
            valid <= 0;
          end else begin
            valid <= 1;
            no_solution <= 0;
            if (modify_attempt == 0) begin
              result <= sorted_array;
            end else begin
              result <= modified_array;
            end
          end
          done <= 1;
        end
      endcase
    end
  end

endmodule