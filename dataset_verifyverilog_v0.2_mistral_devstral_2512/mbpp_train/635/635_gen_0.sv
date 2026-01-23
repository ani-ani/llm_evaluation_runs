module heap_sort (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_elements,
  input [15:0] data_in [15:0],
  output reg [15:0] data_out [15:0],
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    BUILD_HEAP,
    EXTRACT_MAX,
    HEAPIFY,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] heap [15:0];
  reg [3:0] heap_size;
  reg [3:0] current_index;
  reg [3:0] heapify_index;
  reg [3:0] largest_index;
  reg [3:0] swap_temp_index;
  reg [15:0] temp_data;

  // Heapify state machine
  typedef enum logic [1:0] {
    HEAPIFY_IDLE,
    HEAPIFY_COMPARE,
    HEAPIFY_SWAP,
    HEAPIFY_DONE
  } heapify_state_t;

  heapify_state_t heapify_state, next_heapify_state;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      for (int i = 0; i < 16; i = i + 1) begin
        data_out[i] <= 16'b0;
      end
    end
  end

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      heapify_state <= HEAPIFY_IDLE;
      heap_size <= 5'b0;
      current_index <= 5'b0;
      heapify_index <= 5'b0;
      largest_index <= 5'b0;
      swap_temp_index <= 5'b0;
      temp_data <= 16'b0;
      for (int i = 0; i < 16; i = i + 1) begin
        heap[i] <= 16'b0;
      end
    end else begin
      state <= next_state;
      heapify_state <= next_heapify_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    next_heapify_state = heapify_state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = BUILD_HEAP;
          // Initialize heap with input data
          for (int i = 0; i < 16; i = i + 1) begin
            heap[i] = data_in[i];
          end
          heap_size = num_elements - 1;
          current_index = (num_elements >> 1) - 1;
        end
      end

      BUILD_HEAP: begin
        if (current_index == 0) begin
          next_state = EXTRACT_MAX;
          current_index = heap_size;
        end else begin
          next_state = HEAPIFY;
          heapify_index = current_index;
          current_index = current_index - 1;
        end
      end

      EXTRACT_MAX: begin
        if (heap_size == 0) begin
          next_state = DONE;
          done = 1'b1;
          // Copy sorted data to output
          for (int i = 0; i < 16; i = i + 1) begin
            data_out[i] = heap[i];
          end
        end else begin
          // Swap root with last element
          temp_data = heap[0];
          heap[0] = heap[heap_size];
          heap[heap_size] = temp_data;
          heap_size = heap_size - 1;
          next_state = HEAPIFY;
          heapify_index = 0;
        end
      end

      HEAPIFY: begin
        case (heapify_state)
          HEAPIFY_IDLE: begin
            next_heapify_state = HEAPIFY_COMPARE;
            largest_index = heapify_index;
          end

          HEAPIFY_COMPARE: begin
            // Compare with left child
            if ((heapify_index << 1) + 1 <= heap_size && heap[(heapify_index << 1) + 1] > heap[largest_index]) begin
              largest_index = (heapify_index << 1) + 1;
            end
            // Compare with right child
            if ((heapify_index << 1) + 2 <= heap_size && heap[(heapify_index << 1) + 2] > heap[largest_index]) begin
              largest_index = (heapify_index << 1) + 2;
            end

            if (largest_index == heapify_index) begin
              next_heapify_state = HEAPIFY_DONE;
            end else begin
              next_heapify_state = HEAPIFY_SWAP;
            end
          end

          HEAPIFY_SWAP: begin
            // Swap elements
            temp_data = heap[heapify_index];
            heap[heapify_index] = heap[largest_index];
            heap[largest_index] = temp_data;
            heapify_index = largest_index;
            next_heapify_state = HEAPIFY_COMPARE;
          end

          HEAPIFY_DONE: begin
            next_state = BUILD_HEAP;
            next_heapify_state = HEAPIFY_IDLE;
          end
        endcase
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 1'b0;
        end
      end
    endcase
  end

endmodule