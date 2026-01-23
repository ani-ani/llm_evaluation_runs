module sort_numbers (
  input clk,
  input rst_n,
  input start,
  input [319:0] input_str,
  output reg [319:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    PARSE,
    MAP_VALUES,
    SORT,
    CONVERT,
    BUILD_OUTPUT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] char_buffer [0:7];
  reg [3:0] num_values [0:7];
  reg [3:0] sorted_values [0:7];
  reg [7:0] word_buffer [0:7];
  reg [319:0] output_buffer;

  // Counters
  reg [2:0] word_count;
  reg [2:0] char_count;
  reg [2:0] parse_index;
  reg [2:0] sort_pass;
  reg [2:0] sort_index;
  reg [2:0] convert_index;
  reg [2:0] build_index;
  reg [2:0] output_index;

  // Timing counter
  reg [7:0] cycle_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_counter <= 0;
    end else begin
      current_state <= next_state;
      
      if (current_state == DONE && cycle_counter == 200) begin
        done <= 1;
      end
      
      if (start && current_state == IDLE) begin
        cycle_counter <= 0;
      end else if (cycle_counter < 200) begin
        cycle_counter <= cycle_counter + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PARSE;
      end
      PARSE: begin
        if (word_count == 8 || char_count == 40) next_state = MAP_VALUES;
      end
      MAP_VALUES: begin
        if (parse_index == word_count) next_state = SORT;
      end
      SORT: begin
        if (sort_pass == 7 && sort_index == 7) next_state = CONVERT;
      end
      CONVERT: begin
        if (convert_index == word_count) next_state = BUILD_OUTPUT;
      end
      BUILD_OUTPUT: begin
        if (build_index == word_count) next_state = DONE;
      end
      DONE: begin
        if (cycle_counter == 200) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Parse state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      word_count <= 0;
      char_count <= 0;
      parse_index <= 0;
    end else if (current_state == PARSE) begin
      if (input_str[char_count*8 +: 8] == 8'h20 || char_count == 39) begin
        word_count <= word_count + 1;
        char_count <= char_count + 1;
      end else begin
        char_buffer[word_count][char_count[2:0] - parse_index] <= input_str[char_count*8 +: 8];
        char_count <= char_count + 1;
      end
    end
  end

  // Map values state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      parse_index <= 0;
    end else if (current_state == MAP_VALUES) begin
      case (char_buffer[parse_index])
        "zero": num_values[parse_index] <= 4'h0;
        "one": num_values[parse_index] <= 4'h1;
        "two": num_values[parse_index] <= 4'h2;
        "three": num_values[parse_index] <= 4'h3;
        "four": num_values[parse_index] <= 4'h4;
        "five": num_values[parse_index] <= 4'h5;
        "six": num_values[parse_index] <= 4'h6;
        "seven": num_values[parse_index] <= 4'h7;
        "eight": num_values[parse_index] <= 4'h8;
        "nine": num_values[parse_index] <= 4'h9;
        default: num_values[parse_index] <= 4'h0;
      endcase
      parse_index <= parse_index + 1;
    end
  end

  // Sort state (bubble sort)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass <= 0;
      sort_index <= 0;
    end else if (current_state == SORT) begin
      if (sort_index < 7 - sort_pass) begin
        if (num_values[sort_index] > num_values[sort_index + 1]) begin
          reg [3:0] temp = num_values[sort_index];
          num_values[sort_index] <= num_values[sort_index + 1];
          num_values[sort_index + 1] <= temp;
        end
        sort_index <= sort_index + 1;
      end else begin
        sort_index <= 0;
        sort_pass <= sort_pass + 1;
      end
    end
  end

  // Convert state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      convert_index <= 0;
    end else if (current_state == CONVERT) begin
      case (num_values[convert_index])
        4'h0: word_buffer[convert_index] = "zero";
        4'h1: word_buffer[convert_index] = "one";
        4'h2: word_buffer[convert_index] = "two";
        4'h3: word_buffer[convert_index] = "three";
        4'h4: word_buffer[convert_index] = "four";
        4'h5: word_buffer[convert_index] = "five";
        4'h6: word_buffer[convert_index] = "six";
        4'h7: word_buffer[convert_index] = "seven";
        4'h8: word_buffer[convert_index] = "eight";
        4'h9: word_buffer[convert_index] = "nine";
        default: word_buffer[convert_index] = "zero";
      endcase
      convert_index <= convert_index + 1;
    end
  end

  // Build output state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      build_index <= 0;
      output_index <= 0;
      output_buffer <= 0;
    end else if (current_state == BUILD_OUTPUT) begin
      if (build_index < word_count) begin
        for (int i = 0; i < 8; i = i + 1) begin
          if (i < 5) begin
            output_buffer[output_index*8 +: 8] <= word_buffer[build_index][i*8 +: 8];
            output_index <= output_index + 1;
          end
        end
        if (build_index < word_count - 1) begin
          output_buffer[output_index*8 +: 8] <= 8'h20; // space
          output_index <= output_index + 1;
        end
        build_index <= build_index + 1;
      end
    end
  end

  // Output assignment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else if (current_state == DONE && cycle_counter == 200) begin
      result <= output_buffer;
      done <= 1;
    end else if (current_state == IDLE && !start) begin
      done <= 0;
    end
  end

endmodule