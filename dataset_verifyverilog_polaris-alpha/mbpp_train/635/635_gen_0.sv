module heap_sort(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] data_in [0:7],
  output reg [7:0] data_out [0:7],
  output reg done
);

  // Internal registers
  reg [7:0] heap [0:7];

  // State encoding
  typedef enum logic [1:0] {
    IDLE        = 2'b00,
    BUILD_HEAP  = 2'b01,
    SORT        = 2'b10,
    DONE        = 2'b11
  } state_t;

  state_t state, next_state;

  // Control registers
  reg [3:0] root;
  reg [3:0] heap_size;
  reg [3:0] i;
  reg [3:0] j;
  reg [3:0] largest_idx;
  reg [3:0] left_idx;
  reg [3:0] right_idx;

  reg [7:0] root_val;
  reg [7:0] l_val;
  reg [7:0] r_val;
  reg [7:0] largest_val;

  reg [7:0] tmp;

  // Combinational next-state logic and heap operation control
  always @(*) begin
    // Default assignments
    next_state   = state;

    // Preserve current values by default
    // (actual updates occur in sequential always block)

    case (state)
      IDLE: begin
        if (start) begin
          next_state = BUILD_HEAP;
        end
      end

      BUILD_HEAP: begin
        // If all roots processed, move to SORT
        if (root == 4'd15) begin
          next_state = SORT;
        end else begin
          next_state = BUILD_HEAP;
        end
      end

      SORT: begin
        // When heap_size reduced to 1, sorting complete
        if (heap_size <= 4'd1) begin
          next_state = DONE;
        end else begin
          next_state = SORT;
        end
      end

      DONE: begin
        // Wait in DONE until start is deasserted; next start will restart
        if (!start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous active-low reset
      state      <= IDLE;
      done       <= 1'b0;
      root       <= 4'd0;
      heap_size  <= 4'd0;
      i          <= 4'd0;
      j          <= 4'd0;
      largest_idx<= 4'd0;
      left_idx   <= 4'd0;
      right_idx  <= 4'd0;
      root_val   <= 8'd0;
      l_val      <= 8'd0;
      r_val      <= 8'd0;
      largest_val<= 8'd0;
      tmp        <= 8'd0;

      // Clear output array
      data_out[0] <= 8'd0;
      data_out[1] <= 8'd0;
      data_out[2] <= 8'd0;
      data_out[3] <= 8'd0;
      data_out[4] <= 8'd0;
      data_out[5] <= 8'd0;
      data_out[6] <= 8'd0;
      data_out[7] <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;

          if (start) begin
            // Load input to heap; pad unused entries externally with 8'hFF if needed
            heap[0] <= data_in[0];
            heap[1] <= data_in[1];
            heap[2] <= data_in[2];
            heap[3] <= data_in[3];
            heap[4] <= data_in[4];
            heap[5] <= data_in[5];
            heap[6] <= data_in[6];
            heap[7] <= data_in[7];

            // Initialize for build-heap phase
            heap_size <= 4'd8;
            root      <= 4'd3; // Start from floor((n/2)-1) for n=8
            i         <= 4'd0;
            j         <= 4'd0;
          end
        end

        BUILD_HEAP: begin
          // Heapify at index 'root'
          // Capture values
          root_val    <= heap[root];
          left_idx    <= (root << 1) + 4'd1;
          right_idx   <= (root << 1) + 4'd2;

          // Determine largest among root, left, right
          largest_idx <= root;
          largest_val <= heap[root];

          if (left_idx < heap_size) begin
            l_val <= heap[left_idx];
            if (heap[left_idx] > largest_val) begin
              largest_idx <= left_idx;
              largest_val <= heap[left_idx];
            end
          end

          if (right_idx < heap_size) begin
            r_val <= heap[right_idx];
            if (heap[right_idx] > largest_val) begin
              largest_idx <= right_idx;
              largest_val <= heap[right_idx];
            end
          end

          // Perform swap if needed
          if (largest_idx != root) begin
            tmp               <= heap[root];
            heap[root]        <= heap[largest_idx];
            heap[largest_idx] <= tmp;
          end

          // Move to previous root index or flag completion
          if (root > 0) begin
            root <= root - 4'd1;
          end else begin
            // All heapify roots processed; mark sentinel value so next_state will move to SORT
            root <= 4'd15;
          end
        end

        SORT: begin
          // Heap sort extraction: swap max (index 0) with last element of heap
          if (heap_size > 1) begin
            tmp               <= heap[0];
            heap[0]           <= heap[heap_size - 1];
            heap[heap_size-1] <= tmp;

            // Reduce heap size
            heap_size <= heap_size - 4'd1;

            // Sift-down from root to restore max-heap in remaining heap
            i      <= 4'd0;
            j      <= 4'd0;

            // One-step iterative sift-down per cycle (simplified behavioral, bounded by size)
            // Note: For small fixed size=8, this approach completes well within 40 cycles.
            begin
              reg [3:0] cur;
              reg [3:0] l;
              reg [3:0] r;
              reg [3:0] max_i;
              reg [7:0] v_cur;
              reg [7:0] v_l;
              reg [7:0] v_r;

              cur   = 4'd0;

              while (1) begin
                l      = (cur << 1) + 4'd1;
                r      = (cur << 1) + 4'd2;
                max_i  = cur;
                v_cur  = heap[cur];

                if (l < heap_size) begin
                  v_l = heap[l];
                  if (v_l > v_cur) begin
                    max_i = l;
                    v_cur = v_l;
                  end
                end

                if (r < heap_size) begin
                  v_r = heap[r];
                  if (v_r > v_cur) begin
                    max_i = r;
                  end
                end

                if (max_i != cur) begin
                  tmp          <= heap[cur];
                  heap[cur]    <= heap[max_i];
                  heap[max_i]  <= tmp;
                  cur          = max_i;
                end else begin
                  disable while; // End sift-down
                end
              end
            end
          end
        end

        DONE: begin
          // Copy sorted heap to outputs; heap now sorted in ascending order
          data_out[0] <= heap[0];
          data_out[1] <= heap[1];
          data_out[2] <= heap[2];
          data_out[3] <= heap[3];
          data_out[4] <= heap[4];
          data_out[5] <= heap[5];
          data_out[6] <= heap[6];
          data_out[7] <= heap[7];

          done <= 1'b1;
        end

        default: begin
          // Fallback safety
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule