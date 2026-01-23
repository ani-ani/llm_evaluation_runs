module search_frequency (
  input clk,
  input rst_n,
  input start,
  input [3:0] array_size,
  input [7:0][3:0] data,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COUNT,
    FIND_MAX,
    DONE
  } state_t;

  state_t state;
  reg [3:0] count [0:15]; // Frequency counters for values 0-15
  reg [3:0] index; // Current index for counting or finding max
  reg [3:0] current_value; // Current value being checked
  reg [3:0] max_valid; // Maximum valid value found
  reg [3:0] counter; // General purpose counter

  // Initialize all counters to 0
  integer i;
  initial begin
    for (i = 0; i < 16; i = i + 1) begin
      count[i] = 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      result <= 0;
      done <= 0;
      index <= 0;
      current_value <= 0;
      max_valid <= 0;
      counter <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        count[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COUNT;
            index <= 0;
            counter <= 0;
            // Reset frequency counters
            for (i = 0; i < 16; i = i + 1) begin
              count[i] <= 0;
            end
          end
        end

        COUNT: begin
          if (counter < array_size) begin
            // Increment frequency counter for current data element
            current_value <= data[counter];
            count[current_value] <= count[current_value] + 1;
            counter <= counter + 1;
          end else begin
            // Move to FIND_MAX state
            state <= FIND_MAX;
            index <= 15; // Start checking from highest value
            max_valid <= 15; // Default to -1 (15)
          end
        end

        FIND_MAX: begin
          if (index > 0) begin
            // Check if current value is valid (count >= value and value > 0)
            if (count[index] >= index && index > 0) begin
              max_valid <= index; // Found a valid value
              state <= DONE;
            end else begin
              index <= index - 1; // Check next lower value
            end
          end else begin
            // No valid value found, return 15 (-1)
            state <= DONE;
          end
        end

        DONE: begin
          result <= max_valid;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule