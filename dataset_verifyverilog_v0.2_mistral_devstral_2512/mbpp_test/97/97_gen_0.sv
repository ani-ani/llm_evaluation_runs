module frequency_counter (
  input clk,
  input rst_n,
  input start,
  input [2:0] row_idx,
  input [7:0] data_in [7:0],
  output reg [7:0] freq_value,
  output reg [7:0] key_out,
  output reg done,
  output reg valid
);

  parameter NUM_ROWS = 3;
  parameter ELEMENTS_PER_ROW = 8;
  parameter TOTAL_ELEMENTS = NUM_ROWS * ELEMENTS_PER_ROW;
  parameter RAM_DEPTH = 256;

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_ROW,
    COUNTING,
    FINISHED,
    READOUT
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] freq_ram [0:RAM_DEPTH-1];
  reg [7:0] current_key;
  reg [7:0] current_count;
  reg [7:0] element_counter;
  reg [2:0] row_counter;
  reg [2:0] element_idx;
  reg [7:0] readout_counter;

  // Initialize RAM to zeros
  integer i;
  initial begin
    for (i = 0; i < RAM_DEPTH; i = i + 1) begin
      freq_ram[i] = 8'b0;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      element_counter <= 0;
      row_counter <= 0;
      element_idx <= 0;
      readout_counter <= 0;
      current_key <= 0;
      current_count <= 0;
      freq_value <= 0;
      key_out <= 0;
      done <= 0;
      valid <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            element_counter <= 0;
            row_counter <= 0;
            element_idx <= 0;
            done <= 0;
            valid <= 0;
          end
        end

        LOAD_ROW: begin
          // No specific action needed in this state
        end

        COUNTING: begin
          if (element_counter == TOTAL_ELEMENTS - 1) begin
            done <= 1;
          end
        end

        FINISHED: begin
          // Prepare for readout
          readout_counter <= 0;
          current_key <= 0;
        end

        READOUT: begin
          if (readout_counter == RAM_DEPTH - 1) begin
            valid <= 0;
          end
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_ROW;
        end
      end

      LOAD_ROW: begin
        next_state = COUNTING;
      end

      COUNTING: begin
        if (element_counter == TOTAL_ELEMENTS - 1) begin
          next_state = FINISHED;
        end
      end

      FINISHED: begin
        next_state = READOUT;
      end

      READOUT: begin
        if (readout_counter == RAM_DEPTH - 1) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Counting logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        COUNTING: begin
          if (element_counter < TOTAL_ELEMENTS) begin
            // Read current count
            current_count = freq_ram[data_in[element_idx]];
            // Increment count
            freq_ram[data_in[element_idx]] = current_count + 1;
            // Update counters
            element_counter = element_counter + 1;
            element_idx = element_idx + 1;
            if (element_idx == ELEMENTS_PER_ROW) begin
              element_idx = 0;
              row_counter = row_counter + 1;
            end
          end
        end

        READOUT: begin
          if (readout_counter < RAM_DEPTH) begin
            key_out = readout_counter;
            freq_value = freq_ram[readout_counter];
            valid = 1;
            readout_counter = readout_counter + 1;
          end else begin
            valid = 0;
          end
        end
      endcase
    end
  end

endmodule