module tweeper_decoder (
  input clk,
  input rst_n,
  input start,
  input [7:0] i_char,
  input [7:0] o_char,
  input [3:0] i_idx,
  input [3:0] o_idx,
  input i_valid,
  input i_last,
  input o_last,
  output reg [7:0] enc_plus,
  output reg [7:0] enc_minus,
  output reg [1:0] result_code,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] COLLECT = 3'b001;
  localparam [2:0] PROCESS = 3'b010;
  localparam [2:0] VALIDATE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state, next_state;

  // Internal registers
  reg [7:0] i_string [0:15];
  reg [7:0] o_string [0:15];
  reg [3:0] i_count, o_count;
  reg [7:0] plus_mapping, minus_mapping;
  reg plus_found, minus_found;
  reg plus_multiple, minus_multiple;
  reg [7:0] plus_candidate, minus_candidate;
  reg [15:0] counter;

  // Initialize outputs
  initial begin
    enc_plus = 8'b0;
    enc_minus = 8'b0;
    result_code = 2'b00;
    done = 1'b0;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i_count <= 0;
      o_count <= 0;
      plus_found <= 0;
      minus_found <= 0;
      plus_multiple <= 0;
      minus_multiple <= 0;
      plus_candidate <= 0;
      minus_candidate <= 0;
      counter <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (i_last && o_last) next_state = PROCESS;
      end
      PROCESS: begin
        if (counter == 16'hFF) next_state = VALIDATE;
      end
      VALIDATE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_count <= 0;
      o_count <= 0;
    end else if (state == COLLECT && i_valid) begin
      if (i_idx < 16) begin
        i_string[i_idx] <= i_char;
        i_count <= i_idx + 1;
      end
      if (o_idx < 16) begin
        o_string[o_idx] <= o_char;
        o_count <= o_idx + 1;
      end
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
      plus_found <= 0;
      minus_found <= 0;
      plus_multiple <= 0;
      minus_multiple <= 0;
      plus_candidate <= 0;
      minus_candidate <= 0;
    end else if (state == PROCESS) begin
      counter <= counter + 1;
      if (counter < i_count) begin
        // Check for '+' character
        if (i_string[counter] == "+") begin
          if (!plus_found) begin
            plus_found <= 1;
            plus_candidate <= o_string[counter];
          end else if (o_string[counter] != plus_candidate) begin
            plus_multiple <= 1;
          end
        end
        
        // Check for '-' character
        if (i_string[counter] == "-") begin
          if (!minus_found) begin
            minus_found <= 1;
            minus_candidate <= o_string[counter];
          end else if (o_string[counter] != minus_candidate) begin
            minus_multiple <= 1;
          end
        end
      end
    end
  end

  // Validation and output
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enc_plus <= 0;
      enc_minus <= 0;
      result_code <= 0;
      done <= 0;
    end else if (state == VALIDATE) begin
      // Determine result code
      if (plus_multiple || minus_multiple) begin
        result_code <= 2'b11; // Multiple mappings
      end else if (!plus_found && !minus_found) begin
        result_code <= 2'b10; // Any empty
      end else if ((plus_found && !plus_multiple) || (minus_found && !minus_multiple)) begin
        result_code <= 2'b01; // Valid
      end else begin
        result_code <= 2'b00; // Corrupted
      end
      
      // Set encoding outputs
      enc_plus <= plus_found ? plus_candidate : 8'b0;
      enc_minus <= minus_found ? minus_candidate : 8'b0;
      done <= 1'b1;
    end else if (state == DONE && !start) begin
      done <= 1'b0;
    end
  end

endmodule