module string_game_winner(
  input clk,              // clock signal
  input rst_n,            // active-low reset
  input start,            // pulse high to start processing
  input [3:0] str_len,    // string length (1-15 accepted, 0=empty)
  input [7:0] char_in,     // ASCII character input (serial)
  output reg [15:0] results, // bitmask results (1=Ann, 0=Mike)
  output reg done          // high when all results ready
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // State and control signals
  reg [1:0] current_state, next_state;
  reg [3:0] char_counter;
  reg [7:0] running_minimum;
  reg [15:0] next_results;
  reg processing_active;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
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
          next_state = PROCESSING;
        end else begin
          next_state = IDLE;
        end
      end
      PROCESSING: begin
        if (char_counter == str_len - 1) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end
      DONE: begin
        if (start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Control signals and internal registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      char_counter <= 4'b0;
      running_minimum <= 8'd122; // ASCII 'z'
      results <= 16'b0;
      next_results <= 16'b0;
      processing_active <= 1'b0;
      done <= 1'b0;
    end else begin
      case (next_state)
        IDLE: begin
          char_counter <= 4'b0;
          running_minimum <= 8'd122;
          next_results <= 16'b0;
          processing_active <= 1'b0;
          if (start) begin
            // Initialize for new processing
            char_counter <= 4'b0;
            running_minimum <= 8'd122;
            next_results <= 16'b0;
            processing_active <= 1'b1;
            done <= 1'b0;
          end else begin
            done <= done; // Hold done signal
          end
        end
        PROCESSING: begin
          if (processing_active) begin
            // Process current character
            if (char_counter == 0) begin
              // First character always Mike wins
              next_results[0] <= 1'b0;
              running_minimum <= char_in;
            end else begin
              // Check if current_char > running_minimum
              if (char_in > running_minimum) begin
                next_results[char_counter] <= 1'b1; // Ann wins
              end else begin
                next_results[char_counter] <= 1'b0; // Mike wins
              end
              // Update running minimum if current char is smaller
              if (char_in < running_minimum) begin
                running_minimum <= char_in;
              end else begin
                running_minimum <= running_minimum;
              end
            end
            // Increment counter
            char_counter <= char_counter + 1;
          end
          done <= 1'b0;
        end
        DONE: begin
          results <= next_results;
          done <= 1'b1;
          processing_active <= 1'b0;
        end
        default: begin
          char_counter <= 4'b0;
          running_minimum <= 8'd122;
          next_results <= 16'b0;
          processing_active <= 1'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule