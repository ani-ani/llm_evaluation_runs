module heap_sort (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:7],
  output reg [7:0] data_out [0:7],
  output reg done
);

  localparam [1:0] IDLE      = 2'b00;
  localparam [1:0] BUILD_HEAP= 2'b01;
  localparam [1:0] SORT      = 2'b10;
  localparam [1:0] DONE      = 2'b11;

  reg [1:0] state, next_state;

  // Internal heap storage (max-heap during sort)
  reg [7:0] heap [0:7];

  // Build-heap control
  reg [3:0] build_root;     // current root for sift-down
  reg       build_root_inc; // whether to increment root next cycle
  reg       heapify_flag;   // indicates active heapify on current root
  reg [3:0] heapify_root;   // local copy of root for heapify
  reg [3:0] heapify_left;   // left child index during heapify
  reg [3:0] heapify_right;  // right child index during heapify
  reg [3:0] heapify_largest;// running largest during heapify
  reg [3:0] heap_size;      // logical heap size (shrinks during sort)

  // Sort-phase control
  reg sort_root_inc;        // whether to increment j next cycle
  reg [3:0] sort_j;         // boundary for unsorted heap
  reg [3:0] extract_root;   // local root for extract-max (always 0)
  reg [3:0] extract_left;   // left child during extract-max
  reg [3:0] extract_right;  // right child during extract-max
  reg [3:0] extract_largest;// running largest during extract-max
  reg       extracting;     // active flag for extract-max

  integer k; // for display/verification (optional)

  // State register with async reset (active-low)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = BUILD_HEAP;
      end
      BUILD_HEAP: begin
        // Finished building heap when last root has been processed
        if (build_root_inc) next_state = SORT;
      end
      SORT: begin
        // When j has been decremented below 1, heap is fully extracted
        if (sort_root_inc && (sort_j == 4'd0)) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE; // deassert start to accept new sort
      end
      default: next_state = IDLE;
    endcase
  end

  // Combinational flags for state entry conditions
  always @(*) begin
    // Build-heap entry and progression
    build_root_inc = 1'b0;
    if (state == IDLE && next_state == BUILD_HEAP) begin
      // Will set heap_size and prepare build_root on this cycle
    end else if (state == BUILD_HEAP) begin
      // When current root's heapify is done and we can advance
      build_root_inc = (~heapify_flag);
    end
    // Sort-phase entry and progression
    sort_root_inc = 1'b0;
    if (state == BUILD_HEAP && next_state == SORT) begin
      // Will set sort_j and start first extract on this cycle
    end else if (state == SORT) begin
      // When current extract-max is done and we can advance j
      sort_root_inc = (~extracting);
    end
  end

  // Sequential control and datapath (non-blocking assignments)
  always @(posedge clk) begin
    // Defaults (avoid latches)
    heapify_flag  <= 1'b0;
    heapify_root  <= 4'd0;
    heapify_left  <= 4'd0;
    heapify_right <= 4'd0;
    heapify_largest <= 4'd0;
    extracting    <= 1'b0;
    extract_root  <= 4'd0;
    extract_left  <= 4'd0;
    extract_right <= 4'd0;
    extract_largest <= 4'd0;
    done          <= 1'b0;

    case (state)
      IDLE: begin
        // Clear outputs
        for (k = 0; k < 8; k = k + 1) data_out[k] <= 8'hFF;
        done <= 1'b0;

        if (next_state == BUILD_HEAP) begin
          // Load input, pad unused with 8'hFF
          for (k = 0; k < 8; k = k + 1) heap[k] <= data_in[k];
          heap_size    <= 4'd8;
          build_root   <= 4'd3; // floor(8/2)-1; will decrement to 3 on first cycle
        end
      end

      BUILD_HEAP: begin
        // Initialize root at the start of build phase
        if (build_root == 4'd4) begin
          build_root <= 4'd3;
        end

        // Start heapify for current root when not already active
        if (!heapify_flag) begin
          heapify_flag  <= 1'b1;
          heapify_root  <= build_root;
          heapify_left  <= (build_root << 1) + 1;
          heapify_right <= (build_root << 1) + 2;
          heapify_largest <= build_root;
        end else begin
          // One-level sift-down per clock when children are in-bounds
          if (heapify_left < heap_size) begin
            if (heap[heapify_left] > heap[heapify_largest]) begin
              heapify_largest <= heapify_left;
            end
          end
          if ((heapify_right < heap_size) && (heap[heapify_right] > heap[heapify_largest])) begin
            heapify_largest <= heapify_right;
          end

          if (heapify_largest != heapify_root) begin
            // Swap and continue sifting from new position
            heap[heapify_root] <= heap[heapify_largest];
            heap[heapify_largest] <= heap[heapify_root];
            heapify_root  <= heapify_largest;
            heapify_left  <= (heapify_largest << 1) + 1;
            heapify_right <= (heapify_largest << 1) + 2;
            heapify_largest <= heapify_largest;
          end else begin
            // Heapify done for this root
            heapify_flag <= 1'b0;
            if (build_root > 4'd0) begin
              build_root <= build_root - 1;
            end
          end
        end

        if (build_root_inc) begin
          // Move to sort phase
          sort_j <= 4'd7;
        end
      end

      SORT: begin
        // Start of sort: j = heap_size - 1; prepare to extract max
        if (next_state == SORT && state != SORT) begin
          sort_j <= heap_size - 1;
          extracting  <= 1'b1;
          extract_root  <= 4'd0;
          extract_left  <= 4'd1;
          extract_right <= 4'd2;
          extract_largest <= 4'd0;
        end else begin
          // One-level sift-down per clock for extract-max
          if (extracting) begin
            if (extract_left < sort_j) begin
              if (heap[extract_left] > heap[extract_largest]) begin
                extract_largest <= extract_left;
              end
            end
            if ((extract_right < sort_j) && (heap[extract_right] > heap[extract_largest])) begin
              extract_largest <= extract_right;
            end

            if (extract_largest != extract_root) begin
              // Swap and continue sifting
              heap[extract_root] <= heap[extract_largest];
              heap[extract_largest] <= heap[extract_root];
              extract_root  <= extract_largest;
              extract_left  <= (extract_largest << 1) + 1;
              extract_right <= (extract_largest << 1) + 2;
              extract_largest <= extract_largest;
            end else begin
              // Extract-max done for this j: swap max(heap[0]) to end
              heap[4'd0] <= heap[sort_j];
              heap[sort_j] <= heap[4'd0];
              sort_j <= sort_j - 1;
              extracting <= 1'b0;
            end
          end else if (sort_j > 4'd0) begin
            // Start next extraction if more work remains
            extracting  <= 1'b1;
            extract_root  <= 4'd0;
            extract_left  <= 4'd1;
            extract_right <= 4'd2;
            extract_largest <= 4'd0;
          end
        end

        if (sort_root_inc && (sort_j == 4'd0)) begin
          // Done with extraction; output final array
          for (k = 0; k < 8; k = k + 1) data_out[k] <= heap[k];
          done <= 1'b1;
        end
      end

      DONE: begin
        // Hold sorted output and done until start deasserts
        for (k = 0; k < 8; k = k + 1) data_out[k] <= heap[k];
        done <= 1'b1;
      end

      default: begin
        // Safety: force all to known values
        for (k = 0; k < 8; k = k + 1) data_out[k] <= 8'hFF;
        done <= 1'b0;
      end
    endcase
  end

endmodule