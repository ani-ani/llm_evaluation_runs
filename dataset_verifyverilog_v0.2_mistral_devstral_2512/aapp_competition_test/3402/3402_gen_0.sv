module password_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] base_char,
  input [7:0] query_pos [0:15],
  input [5:0] query_len,
  input [7:0] trans_char,
  input [7:0] trans_str [0:15],
  input [5:0] trans_len,
  input trans_valid,
  input trans_done,
  output reg [7:0] result_char,
  output reg result_valid,
  output reg [2:0] state
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_TRANS = 3'b001;
  localparam [2:0] COMPUTE_LENGTHS = 3'b010;
  localparam [2:0] FIND_CHARACTER = 3'b011;
  localparam [2:0] DONE = 3'b100;

  // Transition string storage (26 characters, each with 16-byte string and length)
  reg [7:0] trans_storage [0:25][0:15];
  reg [5:0] trans_lengths [0:25];
  reg [5:0] loaded_count;

  // Length computation storage (64-bit lengths for each character)
  reg [63:0] char_lengths [0:25];
  reg [5:0] current_char_idx;
  reg [63:0] current_length;
  reg [63:0] exponent;
  reg [63:0] base;
  reg [5:0] compute_step;

  // Character finding state
  reg [7:0] current_base_char;
  reg [63:0] current_pos;
  reg [63:0] accumulated_length;
  reg [5:0] query_idx;
  reg [5:0] base_idx;
  reg found;

  // Main state register
  reg [2:0] current_state, next_state;

  // Initialize outputs
  always @(*) begin
    result_char = 8'h00;
    result_valid = 1'b0;
    state = current_state;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      loaded_count <= 0;
      current_char_idx <= 0;
      current_length <= 0;
      exponent <= 0;
      base <= 0;
      compute_step <= 0;
      current_pos <= 0;
      accumulated_length <= 0;
      query_idx <= 0;
      base_idx <= 0;
      found <= 0;
      result_valid <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_TRANS;
      end
      LOAD_TRANS: begin
        if (trans_done) next_state = COMPUTE_LENGTHS;
      end
      COMPUTE_LENGTHS: begin
        if (current_char_idx == 25 && compute_step == 0) next_state = FIND_CHARACTER;
      end
      FIND_CHARACTER: begin
        if (found) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load transitions
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == LOAD_TRANS && trans_valid) begin
      trans_storage[trans_char - 8'h61][0:trans_len-1] <= trans_str[0:trans_len-1];
      trans_lengths[trans_char - 8'h61] <= trans_len;
      loaded_count <= loaded_count + 1;
    end
  end

  // Compute lengths using exponentiation by squaring
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == COMPUTE_LENGTHS) begin
      if (current_char_idx == 0 && compute_step == 0) begin
        // Initialize for first character
        current_length <= trans_lengths[current_char_idx];
        exponent <= 1000; // Assuming K=1000 as example (adjust as needed)
        base <= trans_lengths[current_char_idx];
        compute_step <= 1;
      end else if (compute_step == 1) begin
        // Exponentiation by squaring
        if (exponent == 0) begin
          char_lengths[current_char_idx] <= current_length;
          current_char_idx <= current_char_idx + 1;
          compute_step <= 0;
          if (current_char_idx < 26) begin
            current_length <= trans_lengths[current_char_idx];
            exponent <= 1000;
            base <= trans_lengths[current_char_idx];
          end
        end else if (exponent[0]) begin
          current_length <= current_length * base;
          exponent <= exponent - 1;
        end else begin
          base <= base * base;
          exponent <= exponent >> 1;
        end
      end
    end
  end

  // Find character
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == FIND_CHARACTER) begin
      if (!found) begin
        if (query_idx == 0) begin
          // Initialize for first query byte
          current_pos <= {56'b0, query_pos[0]};
          accumulated_length <= 0;
          base_idx <= 0;
        end else begin
          // Process each character in base string
          if (base_idx < 8) begin
            current_base_char <= base_char;
            if (current_pos < accumulated_length + char_lengths[current_base_char - 8'h61]) begin
              // Found in this character's expansion
              result_char <= current_base_char;
              found <= 1;
            end else begin
              accumulated_length <= accumulated_length + char_lengths[current_base_char - 8'h61];
              base_idx <= base_idx + 1;
            end
          end else begin
            // Move to next query byte
            query_idx <= query_idx + 1;
            if (query_idx < query_len) begin
              current_pos <= {current_pos[55:0], query_pos[query_idx]};
              base_idx <= 0;
            end
          end
        end
      end
    end
  end

  // Set result valid when done
  always @(posedge clk) begin
    if (!rst_n) begin
      result_valid <= 0;
    end else if (current_state == DONE) begin
      result_valid <= 1;
    end else if (start) begin
      result_valid <= 0;
    end
  end

endmodule