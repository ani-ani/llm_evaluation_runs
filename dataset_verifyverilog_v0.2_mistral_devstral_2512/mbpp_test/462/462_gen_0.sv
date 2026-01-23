module power_set_generator (
  input clk,
  input rst_n,
  input start,
  input [3:0] valid_mask,
  input [7:0] element_0,
  input [7:0] element_1,
  input [7:0] element_2,
  input [7:0] element_3,
  output reg [7:0] output_element,
  output reg output_valid,
  output reg output_done,
  output reg [3:0] output_indices
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    GENERATE,
    OUTPUT_ELEMENT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [3:0] subset_counter; // 0-15
  reg [3:0] element_counter; // 0-3
  reg [3:0] current_subset;
  reg [7:0] elements [0:3];

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      subset_counter <= 0;
      element_counter <= 0;
      current_subset <= 0;
      output_valid <= 0;
      output_done <= 0;
      output_element <= 0;
      output_indices <= 0;
    end else begin
      current_state <= next_state;

      // State transitions
      case (current_state)
        IDLE: begin
          if (start) begin
            subset_counter <= 0;
            element_counter <= 0;
            current_subset <= 0;
            output_done <= 0;
            output_valid <= 0;
            next_state <= GENERATE;
          end
        end

        GENERATE: begin
          // Check if current subset has any elements
          if (current_subset & valid_mask) begin
            // Find first set bit in current_subset
            element_counter <= 0;
            while (element_counter < 4 && !(current_subset[element_counter] & valid_mask[element_counter])) begin
              element_counter <= element_counter + 1;
            end

            if (element_counter < 4) begin
              next_state <= OUTPUT_ELEMENT;
            end else begin
              // Shouldn't happen, but handle it
              next_state <= GENERATE;
            end
          end else begin
            // Skip empty subset
            next_state <= GENERATE;
          end
        end

        OUTPUT_ELEMENT: begin
          // Move to next element in subset
          element_counter <= element_counter + 1;

          // Find next set bit
          while (element_counter < 4 && !(current_subset[element_counter] & valid_mask[element_counter])) begin
            element_counter <= element_counter + 1;
          end

          if (element_counter < 4) begin
            next_state <= OUTPUT_ELEMENT;
          end else begin
            // Move to next subset
            subset_counter <= subset_counter + 1;
            current_subset <= subset_counter;

            if (subset_counter == 15) begin
              next_state <= DONE;
            end else begin
              next_state <= GENERATE;
            end
          end
        end

        DONE: begin
          output_done <= 1;
          output_valid <= 0;
          if (!start) begin
            next_state <= IDLE;
          end
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Output logic
  always @(*) begin
    output_valid = 0;
    output_element = 0;
    output_indices = current_subset;

    case (current_state)
      OUTPUT_ELEMENT: begin
        if (element_counter < 4 && (current_subset[element_counter] & valid_mask[element_counter])) begin
          output_valid = 1;
          case (element_counter)
            0: output_element = element_0;
            1: output_element = element_1;
            2: output_element = element_2;
            3: output_element = element_3;
          endcase
        end
      end

      DONE: begin
        output_done = 1;
      end

      default: begin
        output_valid = 0;
        output_done = 0;
      end
    endcase
  end

  // Initialize elements array
  always @(*) begin
    elements[0] = element_0;
    elements[1] = element_1;
    elements[2] = element_2;
    elements[3] = element_3;
  end

endmodule