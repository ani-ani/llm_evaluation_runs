module guessing_circle (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input valid_in,
  input [3:0] count_in,
  input done_in,
  output reg [7:0] result_value,
  output reg result_valid,
  output reg output_done,
  output reg computation_done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COLLECT,
    WAIT_DONE,
    ANALYZE_VALUE,
    OUTPUT_RESULT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // RAM for storing input values (16 entries)
  reg [7:0] ram [0:15];
  reg [3:0] ram_wr_ptr;
  reg [3:0] ram_rd_ptr;

  // Counters and tracking registers
  reg [31:0] value_counter; // Tracks which value we're analyzing (1-255)
  reg [31:0] pos_counter;   // Tracks position in circular buffer
  reg [31:0] output_counter; // Tracks which value we're outputting

  reg [7:0] current_value; // Current value being analyzed
  reg [3:0] total_entries; // Total number of entries received

  reg [7:0] first_pos;     // First position where current_value appears
  reg [7:0] last_pos;      // Last position where current_value appears
  reg [7:0] segment_start; // Start of current contiguous segment
  reg [7:0] segment_end;   // End of current contiguous segment

  reg value_present;      // Flag if current_value exists in RAM
  reg is_contiguous;      // Flag if current_value is contiguous
  reg value_valid;        // Flag if current_value is valid (contiguous)

  reg [7:0] output_value;  // Current value being output
  reg output_valid_flag;  // Current output validity

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      ram_wr_ptr <= 0;
      ram_rd_ptr <= 0;
      value_counter <= 0;
      pos_counter <= 0;
      output_counter <= 0;
      current_value <= 0;
      total_entries <= 0;
      first_pos <= 0;
      last_pos <= 0;
      segment_start <= 0;
      segment_end <= 0;
      value_present <= 0;
      is_contiguous <= 0;
      value_valid <= 0;
      output_value <= 0;
      output_valid_flag <= 0;
      result_value <= 0;
      result_valid <= 0;
      output_done <= 0;
      computation_done <= 0;
    end else begin
      current_state <= next_state;

      // State-specific register updates
      case (current_state)
        IDLE: begin
          if (start) begin
            ram_wr_ptr <= 0;
            total_entries <= 0;
          end
        end

        COLLECT: begin
          if (valid_in) begin
            ram[ram_wr_ptr] <= data_in;
            ram_wr_ptr <= ram_wr_ptr + 1;
          end
          if (done_in) begin
            total_entries <= count_in;
          end
        end

        ANALYZE_VALUE: begin
          if (value_counter == 0) begin
            current_value <= 1;
          end else begin
            current_value <= current_value + 1;
          end

          // Check if current_value exists in RAM
          value_present <= 0;
          for (int i = 0; i < total_entries; i = i + 1) begin
            if (ram[i] == current_value) begin
              value_present <= 1;
              break;
            end
          end

          // If value exists, check contiguity
          if (value_present) begin
            // Find first and last positions
            first_pos <= 0;
            last_pos <= 0;
            for (int i = 0; i < total_entries; i = i + 1) begin
              if (ram[i] == current_value) begin
                if (first_pos == 0) first_pos <= i;
                last_pos <= i;
              end
            end

            // Check if all occurrences are contiguous
            is_contiguous <= 1;
            segment_start <= first_pos;
            segment_end <= first_pos;

            for (int i = first_pos + 1; i < total_entries; i = i + 1) begin
              if (ram[i] == current_value) begin
                if (i != segment_end + 1) begin
                  is_contiguous <= 0;
                  break;
                end
                segment_end <= i;
              end
            end

            // Check circular wrap-around
            if (is_contiguous && (segment_end == total_entries - 1) && (ram[0] == current_value)) begin
              is_contiguous <= 0;
            end

            value_valid <= is_contiguous;
          end else begin
            value_valid <= 0;
          end
        end

        OUTPUT_RESULT: begin
          if (output_counter == 0) begin
            output_value <= 1;
          end else begin
            output_value <= output_value + 1;
          end

          // Check if this value was valid
          output_valid_flag <= 0;
          if (output_value <= 255) begin
            // Re-check validity (simplified for synthesis)
            reg temp_present = 0;
            reg temp_valid = 0;
            reg [7:0] temp_first = 0;
            reg [7:0] temp_last = 0;

            for (int i = 0; i < total_entries; i = i + 1) begin
              if (ram[i] == output_value) begin
                temp_present = 1;
                if (temp_first == 0) temp_first = i;
                temp_last = i;
              end
            end

            if (temp_present) begin
              reg temp_contiguous = 1;
              reg [7:0] temp_segment_end = temp_first;

              for (int i = temp_first + 1; i < total_entries; i = i + 1) begin
                if (ram[i] == output_value) begin
                  if (i != temp_segment_end + 1) begin
                    temp_contiguous = 0;
                    break;
                  end
                  temp_segment_end = i;
                end
              end

              if (temp_contiguous && (temp_segment_end == total_entries - 1) && (ram[0] == output_value)) begin
                temp_contiguous = 0;
              end

              temp_valid = temp_contiguous;
            end

            output_valid_flag <= temp_valid;
          end
        end

        DONE: begin
          computation_done <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end

      COLLECT: begin
        if (done_in) next_state = WAIT_DONE;
      end

      WAIT_DONE: begin
        next_state = ANALYZE_VALUE;
      end

      ANALYZE_VALUE: begin
        if (value_counter == 255) begin
          next_state = OUTPUT_RESULT;
        end else begin
          next_state = ANALYZE_VALUE;
        end
      end

      OUTPUT_RESULT: begin
        if (output_counter == 255) begin
          next_state = DONE;
        end else begin
          next_state = OUTPUT_RESULT;
        end
      end

      DONE: begin
        if (!start) next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_value <= 0;
      result_valid <= 0;
      output_done <= 0;
      computation_done <= 0;
    end else begin
      case (current_state)
        OUTPUT_RESULT: begin
          result_value <= output_value;
          result_valid <= output_valid_flag;
          output_done <= (output_counter == 255);
        end

        DONE: begin
          computation_done <= 1;
        end

        default: begin
          result_value <= 0;
          result_valid <= 0;
          output_done <= 0;
          computation_done <= 0;
        end
      endcase
    end
  end

  // Counter updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      value_counter <= 0;
      pos_counter <= 0;
      output_counter <= 0;
    end else begin
      case (current_state)
        ANALYZE_VALUE: begin
          if (value_counter < 255) begin
            value_counter <= value_counter + 1;
          end
        end

        OUTPUT_RESULT: begin
          if (output_counter < 255) begin
            output_counter <= output_counter + 1;
          end
        end

        default: begin
          value_counter <= 0;
          pos_counter <= 0;
          output_counter <= 0;
        end
      endcase
    end
  end

endmodule