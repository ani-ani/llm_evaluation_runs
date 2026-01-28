module heap_sort(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result [0:15],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BUILD = 2'd1;
    localparam [1:0] EXTRACT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] heap [0:15];
    reg [3:0] i;           // index for loops
    reg [3:0] j;           // index for heapify
    reg [3:0] largest;     // largest element index
    reg [3:0] left;        // left child index
    reg [3:0] right;       // right child index
    reg [3:0] heap_size;   // current heap size
    reg [3:0] temp_idx;    // temporary index for swapping
    reg swap_flag;         // flag to indicate swap needed
    reg [3:0] counter;     // cycle counter for timeout
    localparam [3:0] MAX_CYCLES = 4'd15; // 16 max iterations

    // Helper: swap two elements in heap
    always @(*) begin
        left = (j * 2) + 1;
        right = (j * 2) + 2;
        largest = j;
        
        // Compare with left child
        if (left < heap_size && heap[left] > heap[j]) begin
            largest = left;
        end
        
        // Compare with right child
        if (right < heap_size && heap[right] > heap[largest]) begin
            largest = right;
        end
        
        swap_flag = (largest != j);
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            heap_size <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp_idx <= 4'd0;
            // Initialize result array
            for (int k = 0; k < 16; k = k + 1) begin
                result[k] <= 8'd0;
            end
            // Initialize heap array
            for (int k = 0; k < 16; k = k + 1) begin
                heap[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        // Copy input array to heap
                        for (int k = 0; k < 16; k = k + 1) begin
                            if (k < len)
                                heap[k] <= arr[k];
                            else
                                heap[k] <= 8'd0;
                        end
                        heap_size <= len;
                        i <= (len > 1) ? (len / 2 - 1) : 4'd0; // Start from n/2 - 1
                        j <= 4'd0;
                        state <= BUILD;
                    end
                end
                
                BUILD: begin
                    counter <= counter + 4'd1;
                    
                    if (counter >= MAX_CYCLES) begin
                        // Timeout - go to extract with what we have
                        i <= 4'd0;
                        heap_size <= len;
                        counter <= 4'd0;
                        state <= EXTRACT;
                    end else if (i < len && len > 1) begin
                        // Heapify from i downwards
                        j <= i;
                        // Perform swap if needed in next cycle
                        if (swap_flag) begin
                            // Swap heap[j] with heap[largest]
                            temp_idx <= heap[j];
                            heap[j] <= heap[largest];
                            heap[largest] <= temp_idx;
                            j <= largest;  // Continue from new position
                        end else begin
                            // Move to next parent
                            if (i == 0) begin
                                // Build complete
                                i <= 4'd0;
                                heap_size <= len;
                                counter <= 4'd0;
                                state <= EXTRACT;
                            end else begin
                                i <= i - 4'd1;
                                counter <= 4'd0; // Reset counter for next iteration
                            end
                        end
                    end else begin
                        // Build complete
                        i <= 4'd0;
                        heap_size <= len;
                        counter <= 4'd0;
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    counter <= counter + 4'd1;
                    
                    if (counter >= MAX_CYCLES) begin
                        // Timeout - copy what we have and finish
                        for (int k = 0; k < 16; k = k + 1) begin
                            result[k] <= heap[k];
                        end
                        state <= DONE_STATE;
                    end else if (heap_size > 1) begin
                        // Swap root with last element
                        temp_idx <= heap[0];
                        heap[0] <= heap[heap_size - 1];
                        heap[heap_size - 1] <= temp_idx;
                        
                        // Reduce heap size
                        heap_size <= heap_size - 1;
                        
                        // Heapify from root (index 0)
                        j <= 4'd0;
                        // Need to continue heapify on root (reduces heap_size)
                        // Go to a sub-state for heapify after swap
                        // Use counter to track heapify progress
                        counter <= 4'd0;
                    end else begin
                        // Extraction complete, copy to result
                        for (int k = 0; k < 16; k = k + 1) begin
                            result[k] <= heap[k];
                        end
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule