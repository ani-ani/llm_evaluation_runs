module merge_dictionaries_three (
  input clk,
  input rst_n,
  input start,
  input [7:0] dict1_keys [5:0],
  input [7:0] dict1_vals [5:0],
  input [7:0] dict2_keys [5:0],
  input [7:0] dict2_vals [5:0],
  input [7:0] dict3_keys [5:0],
  input [7:0] dict3_vals [5:0],
  output reg [7:0] merged_keys [5:0],
  output reg [7:0] merged_vals [5:0],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PROC_DICT1,
    PROC_DICT2,
    PROC_DICT3,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] merged_keys_reg [5:0];
  reg [7:0] merged_vals_reg [5:0];
  reg [2:0] unique_count;
  reg [2:0] entry_index;
  reg [1:0] dict_index;
  reg [7:0] current_key;
  reg [7:0] current_val;
  reg key_exists;
  reg [2:0] found_index;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      unique_count <= 0;
      entry_index <= 0;
      dict_index <= 0;
      current_key <= 0;
      current_val <= 0;
      key_exists <= 0;
      found_index <= 0;
      for (int i = 0; i < 6; i++) begin
        merged_keys_reg[i] <= 0;
        merged_vals_reg[i] <= 0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROC_DICT1;
      end
      PROC_DICT1: begin
        if (entry_index == 5) begin
          next_state = PROC_DICT2;
          entry_index = 0;
          dict_index = 1;
        end
      end
      PROC_DICT2: begin
        if (entry_index == 5) begin
          next_state = PROC_DICT3;
          entry_index = 0;
          dict_index = 2;
        end
      end
      PROC_DICT3: begin
        if (entry_index == 5) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (current_state)
        PROC_DICT1: begin
          // Cycle 1: Load current entry
          if (entry_index == 0) begin
            current_key <= dict1_keys[entry_index];
            current_val <= dict1_vals[entry_index];
          end
          // Cycle 2: Check if key exists
          if (entry_index == 1) begin
            key_exists = 0;
            for (int i = 0; i < unique_count; i++) begin
              if (merged_keys_reg[i] == current_key) begin
                key_exists = 1;
                found_index = i;
              end
            end
          end
          // Cycle 3: Add or update
          if (entry_index == 2) begin
            if (current_key != 0) begin
              if (key_exists) begin
                merged_vals_reg[found_index] <= current_val;
              end else if (unique_count < 6) begin
                merged_keys_reg[unique_count] <= current_key;
                merged_vals_reg[unique_count] <= current_val;
                unique_count <= unique_count + 1;
              end
            end
          end
          // Cycle 4: Increment index
          if (entry_index == 3) begin
            entry_index <= entry_index + 1;
          end
        end
        PROC_DICT2: begin
          // Cycle 1: Load current entry
          if (entry_index == 0) begin
            current_key <= dict2_keys[entry_index];
            current_val <= dict2_vals[entry_index];
          end
          // Cycle 2: Check if key exists
          if (entry_index == 1) begin
            key_exists = 0;
            for (int i = 0; i < unique_count; i++) begin
              if (merged_keys_reg[i] == current_key) begin
                key_exists = 1;
                found_index = i;
              end
            end
          end
          // Cycle 3: Add or update
          if (entry_index == 2) begin
            if (current_key != 0) begin
              if (key_exists) begin
                merged_vals_reg[found_index] <= current_val;
              end else if (unique_count < 6) begin
                merged_keys_reg[unique_count] <= current_key;
                merged_vals_reg[unique_count] <= current_val;
                unique_count <= unique_count + 1;
              end
            end
          end
          // Cycle 4: Increment index
          if (entry_index == 3) begin
            entry_index <= entry_index + 1;
          end
        end
        PROC_DICT3: begin
          // Cycle 1: Load current entry
          if (entry_index == 0) begin
            current_key <= dict3_keys[entry_index];
            current_val <= dict3_vals[entry_index];
          end
          // Cycle 2: Check if key exists
          if (entry_index == 1) begin
            key_exists = 0;
            for (int i = 0; i < unique_count; i++) begin
              if (merged_keys_reg[i] == current_key) begin
                key_exists = 1;
                found_index = i;
              end
            end
          end
          // Cycle 3: Add or update
          if (entry_index == 2) begin
            if (current_key != 0) begin
              if (key_exists) begin
                merged_vals_reg[found_index] <= current_val;
              end else if (unique_count < 6) begin
                merged_keys_reg[unique_count] <= current_key;
                merged_vals_reg[unique_count] <= current_val;
                unique_count <= unique_count + 1;
              end
            end
          end
          // Cycle 4: Increment index
          if (entry_index == 3) begin
            entry_index <= entry_index + 1;
          end
        end
      endcase
    end
  end

  // Output assignment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      for (int i = 0; i < 6; i++) begin
        merged_keys[i] <= 0;
        merged_vals[i] <= 0;
      end
    end else begin
      done <= (current_state == DONE);
      for (int i = 0; i < 6; i++) begin
        merged_keys[i] <= merged_keys_reg[i];
        merged_vals[i] <= merged_vals_reg[i];
      end
    end
  end

endmodule