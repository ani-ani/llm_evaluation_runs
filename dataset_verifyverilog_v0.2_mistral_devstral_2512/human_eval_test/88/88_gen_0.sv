module sort_array (
  input clk,
  input rst_n,
  input start,
  input [2:0] array_length,
  input [7:0] array_in [0:7],
  output reg [7:0] array_out [0:7],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_SUM,
    SORT_PASS,
    VERIFY_DONE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] temp_array [0:7];
  reg [2:0] pass_count;
  reg [2:0] swap_count;
  reg [2:0] i;
  reg [7:0] sum;
  reg sort_direction; // 1 for ascending (ODD), 0 for descending (EVEN)

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      current_state <= IDLE;
      pass_count <= 3'd0;
      swap_count <= 3'd0;
      i <= 3'd0;
      sort_direction <= 1'b0;
      for (int j = 0; j < 8; j = j + 1) begin
        temp_array[j] <= 8'd0;
        array_out[j] <= 8'd0;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_SUM;
        end
      end
      CHECK_SUM: begin
        next_state = SORT_PASS;
      end
      SORT_PASS: begin
        if (pass_count == array_length - 1) begin
          next_state = VERIFY_DONE;
        end
      end
      VERIFY_DONE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
        end
        CHECK_SUM: begin
          // Copy input array
          for (int j = 0; j < 8; j = j + 1) begin
            temp_array[j] <= array_in[j];
          end
          // Calculate sum of first and last valid element
          if (array_length > 0) begin
            sum <= array_in[0] + array_in[array_length - 1];
            sort_direction <= sum[0]; // LSB determines odd/even
          end else begin
            sort_direction <= 1'b0; // Default to descending for empty array
          end
          pass_count <= 3'd0;
          swap_count <= 3'd0;
          i <= 3'd0;
        end
        SORT_PASS: begin
          // Perform one pass of bubble sort
          if (i < array_length - 1 - pass_count) begin
            if (sort_direction) begin
              // Ascending: swap if current > next
              if (temp_array[i] > temp_array[i + 1]) begin
                reg [7:0] temp;
                temp = temp_array[i];
                temp_array[i] <= temp_array[i + 1];
                temp_array[i + 1] <= temp;
                swap_count <= swap_count + 1;
              end
            end else begin
              // Descending: swap if current < next
              if (temp_array[i] < temp_array[i + 1]) begin
                reg [7:0] temp;
                temp = temp_array[i];
                temp_array[i] <= temp_array[i + 1];
                temp_array[i + 1] <= temp;
                swap_count <= swap_count + 1;
              end
            end
            i <= i + 1;
          end else begin
            i <= 3'd0;
            if (swap_count == 0) begin
              // Early termination if no swaps
              pass_count <= array_length - 1;
            end else begin
              pass_count <= pass_count + 1;
              swap_count <= 3'd0;
            end
          end
        end
        VERIFY_DONE: begin
          // Copy sorted array to output
          for (int j = 0; j < 8; j = j + 1) begin
            array_out[j] <= temp_array[j];
          end
          done <= 1'b1;
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule