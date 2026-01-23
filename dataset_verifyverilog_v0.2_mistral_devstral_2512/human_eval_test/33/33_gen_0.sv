module sort_third (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [7:0],
  output reg [7:0] data_out [7:0],
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_SORT,
    SWAP,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal array storage
  reg [7:0] internal_array [7:0];

  // Counter for bubble sort passes
  reg [1:0] pass_counter;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      pass_counter <= 2'b0;
      for (int i = 0; i < 8; i = i + 1) begin
        data_out[i] <= 8'b0;
      end
    end else begin
      current_state <= next_state;
      done <= (current_state == DONE);
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            // Load input data
            for (int i = 0; i < 8; i = i + 1) begin
              internal_array[i] <= data_in[i];
            end
            next_state <= CHECK_SORT;
            pass_counter <= 2'b0;
          end else begin
            next_state <= IDLE;
          end
        end

        CHECK_SORT: begin
          next_state <= SWAP;
        end

        SWAP: begin
          if (pass_counter == 2'b11) begin
            next_state <= DONE;
          end else begin
            next_state <= CHECK_SORT;
          end
        end

        DONE: begin
          next_state <= IDLE;
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Bubble sort logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pass_counter <= 2'b0;
    end else if (current_state == CHECK_SORT) begin
      case (pass_counter)
        2'b00: begin
          // Compare and swap index0 and index3
          if (internal_array[0] > internal_array[3]) begin
            reg [7:0] temp;
            temp = internal_array[0];
            internal_array[0] = internal_array[3];
            internal_array[3] = temp;
          end
        end

        2'b01: begin
          // Compare and swap index3 and index6
          if (internal_array[3] > internal_array[6]) begin
            reg [7:0] temp;
            temp = internal_array[3];
            internal_array[3] = internal_array[6];
            internal_array[6] = temp;
          end
        end

        2'b10: begin
          // Compare and swap index0 and index3 again
          if (internal_array[0] > internal_array[3]) begin
            reg [7:0] temp;
            temp = internal_array[0];
            internal_array[0] = internal_array[3];
            internal_array[3] = temp;
          end
        end

        default: begin
          // Do nothing
        end
      endcase
    end
  end

  // Update pass counter
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pass_counter <= 2'b0;
    end else if (current_state == SWAP) begin
      pass_counter <= pass_counter + 1'b1;
    end
  end

  // Output the result when done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i = i + 1) begin
        data_out[i] <= 8'b0;
      end
    end else if (current_state == DONE) begin
      for (int i = 0; i < 8; i = i + 1) begin
        data_out[i] <= internal_array[i];
      end
    end
  end

endmodule