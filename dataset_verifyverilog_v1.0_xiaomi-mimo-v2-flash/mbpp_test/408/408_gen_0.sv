module find_k_smallest_pairs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [2:0] len1,
    input wire [2:0] len2,
    input wire [3:0] k,
    output reg result_valid,
    output reg [7:0] pair_val1,
    output reg [7:0] pair_val2,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] SETUP       = 4'd1;
    localparam [3:0] CHECK_READY = 4'd2;
    localparam [3:0] EXTRACT     = 4'd3;
    localparam [3:0] OUTPUT      = 4'd4;
    localparam [3:0] PUSH1       = 4'd5;
    localparam [3:0] PUSH2       = 4'd6;
    localparam [3:0] CHECK_PUSH1 = 4'd7;
    localparam [3:0] CHECK_PUSH2 = 4'd8;
    localparam [3:0] DONE_STATE  = 4'd9;
    localparam [3:0] CLEANUP     = 4'd10;

    // Heap entry structure
    // Each entry: sum[15:0], i[18:16], j[21:19], valid[22]
    // Total: 23 bits per entry
    reg [22:0] heap [0:15];
    reg [4:0] heap_size;  // 0-16
    reg [4:0] pairs_generated;  // 0-16
    
    // Temporary registers for operations
    reg [15:0] temp_sum;
    reg [2:0] temp_i;
    reg [2:0] temp_j;
    reg [4:0] temp_idx;
    reg [4:0] temp_child;
    reg [4:0] temp_parent;
    reg [4:0] cycle_count;
    
    // Pointer registers for extraction and insertion
    reg [2:0] extract_i;
    reg [2:0] extract_j;
    reg [2:0] push_i;
    reg [2:0] push_j;
    
    // State machine registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] return_state;
    
    // Flags
    reg heap_empty;
    reg heap_full;
    reg parent_exists;
    reg child_exists;
    reg swap_needed;
    reg valid_entry;
    
    // Constants
    localparam [4:0] MAX_HEAP_SIZE = 5'd16;
    localparam [4:0] MAX_PAIRS = 5'd16;
    localparam [4:0] MAX_CYCLES = 5'd25;  // Extra safety margin

    // Helper: Check if index is within bounds for parent/child
    // Parent of i: (i-1)/2
    // Left child of i: 2*i+1
    // Right child of i: 2*i+2
    
    always @(*) begin
        // Check heap empty
        heap_empty = (heap_size == 5'd0);
        heap_full = (heap_size >= MAX_HEAP_SIZE);
        
        // For heapify up: check if parent exists and should swap
        // Parent index calculation
        if (temp_idx > 5'd0) begin
            temp_parent = (temp_idx - 5'd1) >> 1;
            parent_exists = 1'b1;
            // Check if parent sum > current sum (min-heap violation)
            if (heap[temp_parent][15:0] > heap[temp_idx][15:0]) begin
                swap_needed = 1'b1;
            end else begin
                swap_needed = 1'b0;
            end
        end else begin
            parent_exists = 1'b0;
            temp_parent = 5'd0;
            swap_needed = 1'b0;
        end
        
        // For heapify down: check left child
        temp_child = (temp_idx << 1) + 5'd1;  // Left child
        child_exists = (temp_child < heap_size);
        
        // Check if smaller child exists and should swap
        if (child_exists) begin
            // Compare with left child
            if ((temp_child + 5'd1 < heap_size) && (heap[temp_child + 5'd1][15:0] < heap[temp_child][15:0])) begin
                temp_child = temp_child + 5'd1;  // Right child is smaller
            end
            // Check if child sum < current sum
            if (heap[temp_child][15:0] < heap[temp_idx][15:0]) begin
                swap_needed = 1'b1;
            end else begin
                swap_needed = 1'b0;
            end
        end
        
        // Check if a valid pair can be extracted
        valid_entry = 1'b0;
        if (!heap_empty && extract_i < len1 && extract_j < len2) begin
            valid_entry = 1'b1;
        end
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            pair_val1 <= 8'd0;
            pair_val2 <= 8'd0;
            done <= 1'b0;
            heap_size <= 5'd0;
            pairs_generated <= 5'd0;
            cycle_count <= 5'd0;
            temp_idx <= 5'd0;
            temp_child <= 5'd0;
            temp_parent <= 5'd0;
            extract_i <= 3'd0;
            extract_j <= 3'd0;
            push_i <= 3'd0;
            push_j <= 3'd0;
            // Initialize heap entries
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                heap[i] <= 23'd0;
            end
        end else begin
            // Clear done and result_valid flags unless in proper states
            if (state != OUTPUT && state != DONE_STATE) begin
                result_valid <= 1'b0;
                done <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    heap_size <= 5'd0;
                    pairs_generated <= 5'd0;
                    cycle_count <= 5'd0;
                    // Initialize heap to zeros
                    heap[0] <= 23'd0; heap[1] <= 23'd0; heap[2] <= 23'd0; heap[3] <= 23'd0;
                    heap[4] <= 23'd0; heap[5] <= 23'd0; heap[6] <= 23'd0; heap[7] <= 23'd0;
                    heap[8] <= 23'd0; heap[9] <= 23'd0; heap[10] <= 23'd0; heap[11] <= 23'd0;
                    heap[12] <= 23'd0; heap[13] <= 23'd0; heap[14] <= 23'd0; heap[15] <= 23'd0;
                    if (start) begin
                        state <= SETUP;
                    end
                end
                
                SETUP: begin
                    // Push (arr1[0], arr2[0]) into heap
                    if (len1 > 3'd0 && len2 > 3'd0) begin
                        temp_sum <= {8'd0, arr1[0]} + {8'd0, arr2[0]};
                        temp_i <= 3'd0;
                        temp_j <= 3'd0;
                        heap[heap_size] <= {{23{1'b0}}, {8'd0, arr1[0]} + {8'd0, arr2[0]}, 3'd0, 3'd0, 1'b1};
                        heap_size <= 5'd1;
                        temp_idx <= 5'd0;
                        return_state <= CHECK_READY;
                        state <= CHECK_READY;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                CHECK_READY: begin
                    cycle_count <= 5'd0;
                    if (pairs_generated >= k || heap_empty) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    cycle_count <= cycle_count + 5'd1;
                    // Swap root with last element
                    if (heap_size > 5'd1) begin
                        heap[0] <= heap[heap_size - 5'd1];
                        heap[heap_size - 5'd1] <= 23'd0;
                    end
                    heap_size <= heap_size - 5'd1;
                    temp_idx <= 5'd0;  // Start heapify down from root
                    return_state <= OUTPUT;
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    cycle_count <= cycle_count + 5'd1;
                    // Output the extracted pair
                    if (!heap_empty) begin
                        // Find root (min element) in current heap
                        // For simplicity, we'll extract from position 0
                        // Note: after extraction, heapify down would have moved min to root
                        if (heap_size > 5'd0) begin
                            // Extract from current heap[0]
                            if (heap[0][22] == 1'b1) begin
                                extract_i <= heap[0][18:16];
                                extract_j <= heap[0][19:17];  // Fixed: j is at bits 19:17
                                result_valid <= 1'b1;
                                pair_val1 <= arr1[heap[0][18:16]];
                                pair_val2 <= arr2[heap[0][19:17]];
                                pairs_generated <= pairs_generated + 5'd1;
                                // Store for potential push operations
                                push_i <= heap[0][18:16];
                                push_j <= heap[0][19:17];
                                state <= PUSH1;
                            end else begin
                                state <= DONE_STATE;
                            end
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                PUSH1: begin
                    result_valid <= 1'b0;
                    // Check if we need to push (arr1[i], arr2[j+1])
                    if (push_j + 3'd1 < len2) begin
                        temp_sum <= {8'd0, arr1[push_i]} + {8'd0, arr2[push_j + 3'd1]};
                        temp_i <= push_i;
                        temp_j <= push_j + 3'd1;
                        if (!heap_full) begin
                            // Add to end
                            heap[heap_size] <= {{23{1'b0}}, {8'd0, arr1[push_i]} + {8'd0, arr2[push_j + 3'd1]}, push_i, push_j + 3'd1, 1'b1};
                            temp_idx <= heap_size;
                            heap_size <= heap_size + 5'd1;
                            return_state <= PUSH2;
                            state <= CHECK_PUSH1;
                        end else begin
                            state <= PUSH2;
                        end
                    end else begin
                        state <= PUSH2;
                    end
                end
                
                PUSH2: begin
                    // Check if we need to push (arr1[i+1], arr2[0])
                    if (push_j == 3'd0 && push_i + 3'd1 < len1) begin
                        temp_sum <= {8'd0, arr1[push_i + 3'd1]} + {8'd0, arr2[3'd0]};
                        temp_i <= push_i + 3'd1;
                        temp_j <= 3'd0;
                        if (!heap_full) begin
                            // Add to end
                            heap[heap_size] <= {{23{1'b0}}, {8'd0, arr1[push_i + 3'd1]} + {8'd0, arr2[3'd0]}, push_i + 3'd1, 3'd0, 1'b1};
                            temp_idx <= heap_size;
                            heap_size <= heap_size + 5'd1;
                            return_state <= CHECK_READY;
                            state <= CHECK_PUSH2;
                        end else begin
                            state <= CHECK_READY;
                        end
                    end else begin
                        state <= CHECK_READY;
                    end
                end
                
                CHECK_PUSH1: begin
                    // Heapify up for the newly inserted element
                    // Find parent
                    if (temp_idx > 5'd0) begin
                        temp_parent <= (temp_idx - 5'd1) >> 1;
                        if (heap[(temp_idx - 5'd1) >> 1][15:0] > heap[temp_idx][15:0]) begin
                            // Swap needed
                            heap[temp_idx] <= heap[(temp_idx - 5'd1) >> 1];
                            heap[(temp_idx - 5'd1) >> 1] <= {{23{1'b0}}, temp_sum, temp_i, temp_j, 1'b1};
                            temp_idx <= (temp_idx - 5'd1) >> 1;
                            // Continue checking
                            state <= CHECK_PUSH1;
                        end else begin
                            state <= return_state;
                        end
                    end else begin
                        state <= return_state;
                    end
                end
                
                CHECK_PUSH2: begin
                    // Heapify up for the newly inserted element
                    if (temp_idx > 5'd0) begin
                        temp_parent <= (temp_idx - 5'd1) >> 1;
                        if (heap[(temp_idx - 5'd1) >> 1][15:0] > heap[temp_idx][15:0]) begin
                            // Swap needed
                            heap[temp_idx] <= heap[(temp_idx - 5'd1) >> 1];
                            heap[(temp_idx - 5'd1) >> 1] <= {{23{1'b0}}, temp_sum, temp_i, temp_j, 1'b1};
                            temp_idx <= (temp_idx - 5'd1) >> 1;
                            // Continue checking
                            state <= CHECK_PUSH2;
                        end else begin
                            state <= return_state;
                        end
                    end else begin
                        state <= return_state;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    // Hold final pair values
                    if (pairs_generated > 5'd0 && heap_size > 5'd0) begin
                        pair_val1 <= arr1[heap[0][18:16]];
                        pair_val2 <= arr2[heap[0][19:17]];
                    end
                    state <= CLEANUP;
                end
                
                CLEANUP: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule