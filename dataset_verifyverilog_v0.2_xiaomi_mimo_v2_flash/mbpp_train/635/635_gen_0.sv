module heap_sort(
    input clk,
    input rst_n,
    input start,
    input [4:0] num_elements,
    input [15:0] data_in [15:0],
    output reg [15:0] data_out [15:0],
    output reg done
);

    // States for main FSM
    localparam IDLE = 3'b000;
    localparam BUILD_HEAP = 3'b001;
    localparam EXTRACT_MAX = 3'b010;
    localparam HEAPIFY = 3'b011;
    localparam DONE = 3'b100;

    // Registers for state machine
    reg [2:0] current_state;
    reg [2:0] next_state;

    // Registers for heap operations
    reg [15:0] array_reg [15:0];  // In-place array storage
    reg [4:0] heap_size;          // Current heap size
    reg [4:0] i;                  // General index counter
    reg [4:0] j;                  // Secondary index
    reg [4:0] largest;            // Index of largest element
    reg [4:0] parent;             // Parent index for heapify
    reg [4:0] left;               // Left child index
    reg [4:0] right;              // Right child index
    
    // Temporary swap registers
    reg [15:0] temp;
    
    // Heapify control registers
    reg heapify_done;
    reg heapify_start;
    reg [4:0] heapify_root;
    
    // Counter for loop iterations
    reg [4:0] loop_counter;
    reg [4:0] extract_counter;
    
    // Combinational logic for heapify indices
    always @(*) begin
        left = (2 * parent) + 1;
        right = (2 * parent) + 2;
    end

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            heap_size <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            loop_counter <= 5'd0;
            extract_counter <= 5'd0;
            heapify_start <= 1'b0;
            // Reset output array
            for (integer k = 0; k < 16; k = k + 1) begin
                data_out[k] <= 16'b0;
            end
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input array
                        for (integer k = 0; k < 16; k = k + 1) begin
                            array_reg[k] <= data_in[k];
                        end
                        heap_size <= num_elements;
                        i <= num_elements / 2 - 1;
                        loop_counter <= 5'd0;
                        extract_counter <= 5'd0;
                    end
                end
                
                BUILD_HEAP: begin
                    // Call heapify on node i, decrement i
                    if (i > 0) begin
                        i <= i - 1;
                    end
                end
                
                HEAPIFY: begin
                    // Perform heapify operation
                    // Find largest among parent, left, and right
                    largest <= parent;
                    
                    // Check left child
                    if (left < heap_size && array_reg[left] > array_reg[largest]) begin
                        largest <= left;
                    end
                    
                    // Check right child (combinational check needs to be delayed for sequential)
                    // We need to check right in next cycle or use combinational logic
                end
                
                EXTRACT_MAX: begin
                    // Swap root with last element
                    temp <= array_reg[0];
                    array_reg[0] <= array_reg[heap_size - 1];
                    array_reg[heap_size - 1] <= temp;
                    
                    // Decrement heap size
                    heap_size <= heap_size - 1;
                    
                    // Set parent for heapify
                    parent <= 5'd0;
                end
                
                DONE: begin
                    // Copy to output
                    for (integer k = 0; k < 16; k = k + 1) begin
                        if (k < num_elements)
                            data_out[k] <= array_reg[k];
                        else
                            data_out[k] <= 16'b0;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = BUILD_HEAP;
                else
                    next_state = IDLE;
            end
            
            BUILD_HEAP: begin
                if (num_elements == 0)
                    next_state = DONE;
                else if (i < 5'd16 && i >= 0) begin
                    // Need to process heapify for current i
                    next_state = HEAPIFY;
                end else begin
                    // Finished building heap, start extraction
                    next_state = EXTRACT_MAX;
                end
            end
            
            HEAPIFY: begin
                // Perform one step of heapify
                // This is simplified - actual heapify would need multiple cycles
                next_state = BUILD_HEAP;
            end
            
            EXTRACT_MAX: begin
                if (heap_size > 1) begin
                    // Need to heapify the root
                    parent <= 5'd0;
                    next_state = HEAPIFY;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Improved combinational heapify logic
    reg [4:0] largest_temp;
    reg do_swap;
    reg [15:0] temp_val;
    
    always @(*) begin
        largest_temp = parent;
        left = (2 * parent) + 1;
        right = (2 * parent) + 2;
        
        if (left < heap_size && array_reg[left] > array_reg[largest_temp]) begin
            largest_temp = left;
        end
        
        if (right < heap_size && array_reg[right] > array_reg[largest_temp]) begin
            largest_temp = right;
        end
        
        do_swap = (largest_temp != parent);
        temp_val = array_reg[parent];
    end

    // Sequential heapify execution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (current_state == HEAPIFY) begin
                // Perform heapify step
                if (do_swap) begin
                    // Swap parent with largest
                    array_reg[parent] <= array_reg[largest_temp];
                    array_reg[largest_temp] <= temp_val;
                    
                    // Continue heapify on the swapped child
                    parent <= largest_temp;
                end
                // If no swap needed or after swap, continue to next state
            end else if (current_state == BUILD_HEAP) begin
                if (i < num_elements && i >= 1) begin
                    // Initialize parent for heapify
                    parent <= i;
                end
            end
        end
    end

endmodule
