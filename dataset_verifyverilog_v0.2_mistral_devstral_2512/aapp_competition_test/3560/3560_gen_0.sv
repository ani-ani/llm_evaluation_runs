module barbarian_substring_matcher (
  input clk,
  input rst_n,
  input start,
  input [2:0] operation_type,
  input [2:0] barbarian_id,
  input [63:0] string_input,
  input [2:0] string_length,
  output reg [15:0] result,
  output reg done,
  output reg valid
);

  // State encoding
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_PATTERN = 3'b001;
  localparam [2:0] PROCESS_TYPE1 = 3'b010;
  localparam [2:0] PROCESS_TYPE2 = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state, next_state;

  // Barbarian patterns (8 patterns, 64 bits each)
  reg [63:0] patterns [0:7];
  reg [2:0] pattern_lengths [0:7];
  reg [15:0] counters [0:7];

  // Internal registers
  reg [2:0] current_barbarian;
  reg [2:0] current_position;
  reg [2:0] current_char;
  reg [2:0] pattern_index;
  reg [2:0] pattern_char;
  reg match_found;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      result <= 0;
      current_barbarian <= 0;
      current_position <= 0;
      current_char <= 0;
      pattern_index <= 0;
      pattern_char <= 0;
      match_found <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (operation_type == 0) begin
            next_state = LOAD_PATTERN;
          end else if (operation_type == 1) begin
            next_state = PROCESS_TYPE1;
          end else if (operation_type == 2) begin
            next_state = PROCESS_TYPE2;
          end
        end
      end
      LOAD_PATTERN: begin
        if (pattern_index == 7) begin
          next_state = IDLE;
        end
      end
      PROCESS_TYPE1: begin
        if (current_barbarian == 7 && current_position == 0 && current_char == 0) begin
          next_state = DONE;
        end
      end
      PROCESS_TYPE2: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Pattern loading
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) begin
        patterns[i] <= 0;
        pattern_lengths[i] <= 0;
        counters[i] <= 0;
      end
      pattern_index <= 0;
    end else if (state == LOAD_PATTERN && start) begin
      patterns[pattern_index] <= string_input;
      pattern_lengths[pattern_index] <= string_length;
      pattern_index <= pattern_index + 1;
    end
  end

  // Type 1 processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_barbarian <= 0;
      current_position <= 0;
      current_char <= 0;
      match_found <= 0;
    end else if (state == PROCESS_TYPE1) begin
      if (current_char == 0 && current_position == 0) begin
        match_found <= 0;
      end

      if (!match_found) begin
        if (current_char == 0) begin
          // Check if pattern length is valid
          if (pattern_lengths[current_barbarian] == 0) begin
            current_barbarian <= current_barbarian + 1;
            current_position <= 0;
            current_char <= 0;
          end else if (current_position > (string_length - pattern_lengths[current_barbarian])) begin
            current_barbarian <= current_barbarian + 1;
            current_position <= 0;
            current_char <= 0;
          end
        end

        if (current_char < pattern_lengths[current_barbarian]) begin
          // Compare characters
          if (patterns[current_barbarian][(current_char * 8) +: 8] == string_input[((current_position + current_char) * 8) +: 8]) begin
            if (current_char == (pattern_lengths[current_barbarian] - 1)) begin
              // Full match found
              counters[current_barbarian] <= counters[current_barbarian] + 1;
              match_found <= 1;
            end
            current_char <= current_char + 1;
          end else begin
            current_position <= current_position + 1;
            current_char <= 0;
          end
        end
      end else begin
        current_barbarian <= current_barbarian + 1;
        current_position <= 0;
        current_char <= 0;
        match_found <= 0;
      end
    end
  end

  // Type 2 processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      valid <= 0;
    end else if (state == PROCESS_TYPE2) begin
      result <= counters[barbarian_id - 1];
      valid <= 1;
    end else if (state == DONE) begin
      valid <= 0;
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule