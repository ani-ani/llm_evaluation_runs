module spell_power_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_index,
  input valid_input,
  output reg [7:0] power,
  output reg done
);

  // States
  typedef enum logic [1:0] {
    IDLE,
    COLLECTING,
    CHECKING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Character memory (16x8-bit)
  reg [7:0] char_mem [0:15];
  reg [3:0] mem_index;

  // Checking variables
  reg [3:0] start_pos;  // Start position of substring
  reg [3:0] substr_len; // Length of substring (4, 8, 12, 16)
  reg [1:0] w_len;      // Length of w (1, 2, 3, 4)
  reg [7:0] max_power;  // Maximum valid power found

  // Counters for checking
  reg [3:0] check_counter;
  reg [3:0] pos_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      mem_index <= 0;
      start_pos <= 0;
      substr_len <= 0;
      w_len <= 0;
      max_power <= 0;
      check_counter <= 0;
      pos_counter <= 0;
      power <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start && valid_input && char_index == 0) begin
          next_state = COLLECTING;
        end
      end
      COLLECTING: begin
        if (mem_index == 15 && valid_input) begin
          next_state = CHECKING;
        end
      end
      CHECKING: begin
        if (check_counter == 15 && pos_counter == 15) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Collecting state: store characters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_index <= 0;
    end else if (current_state == COLLECTING && valid_input) begin
      char_mem[char_index] <= char_in;
      if (char_index == mem_index) begin
        mem_index <= mem_index + 1;
      end
    end
  end

  // Checking state: find maximum power
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_pos <= 0;
      substr_len <= 0;
      w_len <= 0;
      check_counter <= 0;
      pos_counter <= 0;
      max_power <= 0;
    end else if (current_state == CHECKING) begin
      // Check all possible start positions and lengths
      if (check_counter < 15) begin
        start_pos <= check_counter;
        substr_len <= 4;
        w_len <= 1;
        pos_counter <= 0;
      end else if (pos_counter < 15) begin
        // Check current substring
        if (is_valid_pattern(start_pos, substr_len, w_len, char_mem)) begin
          if (substr_len > max_power) begin
            max_power <= substr_len;
          end
        end
        // Move to next w_len or substr_len
        if (w_len == 4) begin
          if (substr_len == 16) begin
            pos_counter <= pos_counter + 1;
            check_counter <= check_counter + 1;
          end else begin
            substr_len <= substr_len + 4;
            w_len <= 1;
          end
        end else begin
          w_len <= w_len + 1;
        end
      end
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      power <= 0;
      done <= 0;
    end else if (current_state == DONE) begin
      power <= max_power;
      done <= 1;
    end else begin
      done <= 0;
    end
  end

  // Function to check if substring matches ww^Rww^R
  function automatic bit is_valid_pattern;
    input [3:0] start;
    input [3:0] len;
    input [1:0] w_len;
    input [7:0] mem [0:15];
    bit valid;
    integer i, j;

    begin
      valid = 1;
      // Check if substring can be split into ww^Rww^R
      for (i = 0; i < len; i = i + 1) begin
        if (i < w_len) begin
          // First w
          j = i;
        end else if (i < 2*w_len) begin
          // w^R
          j = 2*w_len - 1 - i;
        end else if (i < 3*w_len) begin
          // Second w
          j = i - 2*w_len;
        end else begin
          // Second w^R
          j = 4*w_len - 1 - i;
        end
        if (mem[start + i] != mem[start + j]) begin
          valid = 0;
        end
      end
      is_valid_pattern = valid;
    end
  endfunction

endmodule