module max_aggregate (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_entries,
  input [63:0] name_in,
  input [7:0] marks_in,
  input valid_in,
  output reg [63:0] result_name,
  output reg [9:0] result_total,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    ACCUMULATE,
    FIND_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Accumulator register file (8 entries)
  reg [63:0] name_reg [0:7];
  reg [9:0] total_reg [0:7];

  // Internal counters and registers
  reg [2:0] entry_count;
  reg [2:0] search_idx;
  reg [2:0] max_idx;
  reg [9:0] max_total;
  reg name_found;
  reg [2:0] empty_slot;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      entry_count <= 0;
      search_idx <= 0;
      max_idx <= 0;
      max_total <= 0;
      name_found <= 0;
      empty_slot <= 0;
      done <= 0;
      error <= 0;
      result_name <= 0;
      result_total <= 0;

      // Initialize accumulator
      for (int i = 0; i < 8; i++) begin
        name_reg[i] <= 0;
        total_reg[i] <= 0;
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
        if (start) begin
          if (num_entries == 0) begin
            next_state = DONE;
            error = 1;
          end else begin
            next_state = ACCUMULATE;
            entry_count = 0;
          end
        end
      end

      ACCUMULATE: begin
        if (entry_count == num_entries - 1) begin
          next_state = FIND_MAX;
          max_idx = 0;
          max_total = total_reg[0];
        end
      end

      FIND_MAX: begin
        if (search_idx == 7) begin
          next_state = DONE;
          done = 1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
          error = 0;
        end
      end
    endcase
  end

  // Accumulate logic
  always @(posedge clk) begin
    if (current_state == ACCUMULATE && valid_in) begin
      // Search for matching name
      name_found = 0;
      for (int i = 0; i < 8; i++) begin
        if (name_reg[i] == name_in && name_reg[i] != 0) begin
          name_found = 1;
          total_reg[i] <= total_reg[i] + $signed(marks_in);
        end
      end

      // If not found, store in empty slot
      if (!name_found) begin
        empty_slot = 0;
        for (int i = 0; i < 8; i++) begin
          if (name_reg[i] == 0) begin
            empty_slot = i;
            break;
          end
        end
        if (empty_slot < 8) begin
          name_reg[empty_slot] <= name_in;
          total_reg[empty_slot] <= $signed(marks_in);
        end
      end

      entry_count <= entry_count + 1;
    end
  end

  // Find max logic
  always @(posedge clk) begin
    if (current_state == FIND_MAX) begin
      if (total_reg[search_idx] > max_total) begin
        max_total = total_reg[search_idx];
        max_idx = search_idx;
      end
      search_idx <= search_idx + 1;
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (current_state == DONE) begin
      result_name <= name_reg[max_idx];
      result_total <= max_total;
    end
  end

endmodule