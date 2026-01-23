module string_formatter (
  input clk,
  input rst_n,
  input start,
  input [7:0] list_data [0:7],
  input [2:0] list_length,
  output reg [7:0] result_strings [0:7][0:4],
  output reg done,
  output reg [2:0] valid_count
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;

  reg [1:0] state = IDLE;
  reg [2:0] element_counter = 0;
  reg [1:0] char_counter = 0;

  // Format string constants
  localparam [7:0] TEMP_STRING [0:3] = '{'t','e','m','p'};

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      element_counter <= 0;
      char_counter <= 0;
      done <= 0;
      valid_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            element_counter <= 0;
            char_counter <= 0;
            done <= 0;
            valid_count <= 0;
          end
        end
        PROCESSING: begin
          // Process each character of the format string
          if (char_counter < 4) begin
            // Write 'temp' characters
            result_strings[element_counter][char_counter] <= TEMP_STRING[char_counter];
            char_counter <= char_counter + 1;
          end else if (char_counter == 4) begin
            // Write input character
            result_strings[element_counter][4] <= list_data[element_counter];
            char_counter <= char_counter + 1;
          end else begin
            // Write null terminator and move to next element
            result_strings[element_counter][5] <= 8'h00;
            char_counter <= 0;
            element_counter <= element_counter + 1;
            valid_count <= element_counter + 1;
            
            if (element_counter == list_length - 1) begin
              state <= DONE;
              done <= 1;
            end
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule