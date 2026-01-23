module secret_message (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input load,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal buffer for characters
  reg [7:0] char_buffer [0:15];
  reg [3:0] buffer_index;
  reg [3:0] actual_length;

  // Processing variables
  reg [3:0] i, d, L;
  reg [3:0] max_count;
  reg [31:0] count [0:255]; // Assuming max 256 unique strings
  reg [7:0] current_string [0:15];
  reg [3:0] current_string_length;

  // Temporary variables for processing
  reg [3:0] temp_i, temp_d, temp_L;
  reg [7:0] temp_char;
  reg [31:0] temp_count;
  reg [3:0] temp_max;

  // Initialize counts
  integer j, k;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      buffer_index <= 0;
      actual_length <= 0;
      done <= 0;
      result <= 0;
      // Initialize counts
      for (j = 0; j < 256; j = j + 1) begin
        count[j] <= 0;
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
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load && buffer_index == 15) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (i == actual_length && d == 15 && L == actual_length) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load characters into buffer
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buffer_index <= 0;
      actual_length <= 0;
    end else if (current_state == LOAD && load) begin
      char_buffer[buffer_index] <= char_in;
      buffer_index <= buffer_index + 1;
      actual_length <= buffer_index + 1;
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      d <= 1;
      L <= 1;
      max_count <= 0;
      result <= 0;
    end else if (current_state == PROCESSING) begin
      // Extract current hidden string
      for (k = 0; k < L; k = k + 1) begin
        current_string[k] <= char_buffer[i + k * d];
      end
      current_string_length <= L;

      // Calculate hash for the current string
      temp_count = 0;
      for (k = 0; k < current_string_length; k = k + 1) begin
        temp_count = temp_count * 256 + current_string[k];
      end
      temp_count = temp_count % 256; // Simple hash

      // Update count
      count[temp_count] <= count[temp_count] + 1;

      // Update max count
      if (count[temp_count] > max_count) begin
        max_count <= count[temp_count];
      end

      // Move to next progression
      if (i + (L) * d < actual_length) begin
        L <= L + 1;
      end else if (d < 15) begin
        i <= 0;
        d <= d + 1;
        L <= 1;
      end else if (i < actual_length - 1) begin
        i <= i + 1;
        d <= 1;
        L <= 1;
      end else begin
        // Processing complete
        result <= max_count * 65536; // Q16.16 format
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule