module LargestKMFreeSubset (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] k,
    input wire [15:0] arr_0,
    input wire [15:0] arr_1,
    input wire [15:0] arr_2,
    input wire [15:0] arr_3,
    input wire [15:0] arr_4,
    input wire [15:0] arr_5,
    input wire [15:0] arr_6,
    input wire [15:0] arr_7,
    input wire [15:0] arr_8,
    input wire [15:0] arr_9,
    input wire [15:0] arr_10,
    input wire [15:0] arr_11,
    input wire [15:0] arr_12,
    input wire [15:0] arr_13,
    input wire [15:0] arr_14,
    input wire [15:0] arr_15,
    output reg [4:0] count,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD          = 4'd1;
    localparam [3:0] SORT_INIT     = 4'd2;
    localparam [3:0] SORT_COMPARE  = 4'd3;
    localparam [3:0] SORT_SWAP     = 4'd4;
    localparam [3:0] SORT_CHECK    = 4'd5;
    localparam [3:0] TRAVERSE_INIT = 4'd6;
    localparam [3:0] TRAVERSE_CHECK = 4'd7;
    localparam [3:0] TRAVERSE_MARK = 4'd8;
    localparam [3:0] TRAVERSE_NEXT = 4'd9;
    localparam [3:0] FINISH        = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Array storage (16 elements of 16 bits each)
    reg [15:0] arr [0:15];
    
    // Mark array (0=valid, 1=excluded)
    reg [15:0] marked;
    
    // Loop counters
    reg [3:0] i;  // i index for bubble sort outer loop
    reg [3:0] j;  // j index for bubble sort inner loop
    reg [3:0] t;  // index for traverse loop
    
    // Bubble sort flags
    reg swapped;
    reg [15:0] temp_val;
    
    // Traverse flags
    reg [15:0] current_val;
    reg [3:0] k_index;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd500;
    
    integer m;  // For initialization loops

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            count <= 5'd0;
            done <= 1'b0;
            
            // Initialize array
            for (m = 0; m < 16; m = m + 1) begin
                arr[m] <= 16'd0;
            end
            
            marked <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            t <= 4'd0;
            swapped <= 1'b0;
            temp_val <= 16'd0;
            current_val <= 16'd0;
            k_index <= 4'd0;
            cycle_count <= 10'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 5'd0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load input array (using individual element assignment)
                    arr[0] <= arr_0;
                    arr[1] <= arr_1;
                    arr[2] <= arr_2;
                    arr[3] <= arr_3;
                    arr[4] <= arr_4;
                    arr[5] <= arr_5;
                    arr[6] <= arr_6;
                    arr[7] <= arr_7;
                    arr[8] <= arr_8;
                    arr[9] <= arr_9;
                    arr[10] <= arr_10;
                    arr[11] <= arr_11;
                    arr[12] <= arr_12;
                    arr[13] <= arr_13;
                    arr[14] <= arr_14;
                    arr[15] <= arr_15;
                    
                    marked <= 16'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    t <= 4'd0;
                    
                    state <= SORT_INIT;
                end
                
                SORT_INIT: begin
                    // Initialize bubble sort
                    i <= 4'd0;
                    swapped <= 1'b0;
                    state <= SORT_COMPARE;
                end
                
                SORT_COMPARE: begin
                    // Check if we need to swap arr[j] and arr[j+1]
                    if (j < n - 1) begin
                        if (arr[j] > arr[j + 1]) begin
                            state <= SORT_SWAP;
                        end else begin
                            state <= SORT_CHECK;
                        end
                    end else begin
                        state <= SORT_CHECK;
                    end
                end
                
                SORT_SWAP: begin
                    // Swap elements
                    temp_val <= arr[j];
                    arr[j] <= arr[j + 1];
                    arr[j + 1] <= temp_val;
                    swapped <= 1'b1;
                    state <= SORT_CHECK;
                end
                
                SORT_CHECK: begin
                    // Move to next j
                    if (j < n - 1) begin
                        j <= j + 4'd1;
                        state <= SORT_COMPARE;
                    end else begin
                        // End of inner loop
                        if (swapped) begin
                            i <= i + 4'd1;
                            j <= 4'd0;
                            swapped <= 1'b0;
                            state <= SORT_INIT;
                        end else begin
                            // Sorting complete
                            state <= TRAVERSE_INIT;
                        end
                    end
                end
                
                TRAVERSE_INIT: begin
                    // Initialize traverse
                    t <= 4'd0;
                    marked <= 16'd0;
                    count <= 5'd0;
                    state <= TRAVERSE_CHECK;
                end
                
                TRAVERSE_CHECK: begin
                    if (t < n) begin
                        // Check if current element is already marked
                        if (marked[t]) begin
                            state <= TRAVERSE_NEXT;
                        end else begin
                            state <= TRAVERSE_MARK;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                TRAVERSE_MARK: begin
                    // Count this element
                    count <= count + 5'd1;
                    current_val <= arr[t];
                    marked[t] <= 1'b1;
                    k_index <= 4'd0;
                    state <= TRAVERSE_NEXT;
                end
                
                TRAVERSE_NEXT: begin
                    // Find and mark x*k in remaining elements
                    if (k_index < n) begin
                        // Check if element matches current_val * k
                        // But need to be careful about overflow and matching
                        if (!marked[k_index] && (k_index > t)) begin
                            // Check if arr[k_index] == current_val * k
                            // Need to handle potential overflow - only compare if product fits in 16 bits
                            // For simplicity, we'll assume k is small enough or we compare directly
                            if (k == 16'd1) begin
                                // Special case: k=1 means all multiples are the same number
                                if (arr[k_index] == current_val) begin
                                    marked[k_index] <= 1'b1;
                                end
                            end else begin
                                // General case: check if arr[k_index] == current_val * k
                                // We need to compute current_val * k, but might overflow
                                // To avoid overflow, we check if arr[k_index] / current_val == k
                                // (assuming current_val != 0)
                                if (current_val != 16'd0) begin
                                    if (arr[k_index] / current_val == k && arr[k_index] % current_val == 16'd0) begin
                                        marked[k_index] <= 1'b1;
                                    end
                                end
                            end
                        end
                        k_index <= k_index + 4'd1;
                        state <= TRAVERSE_NEXT;
                    end else begin
                        // Move to next element in traverse
                        t <= t + 4'd1;
                        state <= TRAVERSE_CHECK;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety: increment cycle counter and timeout if needed
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 10'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end else begin
                cycle_count <= 10'd0;
            end
        end
    end

endmodule