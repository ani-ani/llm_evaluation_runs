module find_kth_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1_in,
    input wire [7:0] arr2_in,
    output reg [3:0] arr1_addr,
    output reg [3:0] arr2_addr,
    input wire [3:0] arr1_len,
    input wire [3:0] arr2_len,
    input wire [4:0] k,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FETCH   = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] MERGE   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Pointer registers (5-bit for up to 32 elements)
    reg [4:0] i;  // pointer for array1
    reg [4:0] j;  // pointer for array2
    reg [4:0] d;  // pointer for destination array
    
    // Internal storage: 32 x 8-bit array
    reg [7:0] merged_arr [0:31];
    
    // Temp storage for comparison
    reg [7:0] temp_arr1;
    reg [7:0] temp_arr2;
    
    // Counter for COMPLETE state
    reg [4:0] copy_ptr;
    reg [4:0] k_index;
    
    // Control flags
    reg arr1_done;
    reg arr2_done;
    reg fetch_pending;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = FETCH;
                else
                    next_state = IDLE;
            end
            
            FETCH: begin
                // We fetch one cycle, then compare next
                next_state = COMPARE;
            end
            
            COMPARE: begin
                // If both arrays have data, merge
                // If one exhausted, go to merge for the other
                if (!arr1_done && !arr2_done)
                    next_state = MERGE;
                else if (arr1_done && !arr2_done)
                    next_state = MERGE;
                else if (!arr1_done && arr2_done)
                    next_state = MERGE;
                else
                    next_state = COMPLETE;
            end
            
            MERGE: begin
                // After merging, check if we need more
                if (d >= (arr1_len + arr2_len - 5'd1))
                    next_state = COMPLETE;
                else if (arr1_done && arr2_done)
                    next_state = COMPLETE;
                else
                    next_state = FETCH;
            end
            
            COMPLETE: begin
                // Read from internal array
                if (copy_ptr == k_index)
                    next_state = IDLE;
                else
                    next_state = COMPLETE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            arr1_addr <= 4'd0;
            arr2_addr <= 4'd0;
            i <= 5'd0;
            j <= 5'd0;
            d <= 5'd0;
            copy_ptr <= 5'd0;
            k_index <= 5'd0;
            arr1_done <= 1'b0;
            arr2_done <= 1'b0;
            fetch_pending <= 1'b0;
            cycle_count <= 8'd0;
            temp_arr1 <= 8'd0;
            temp_arr2 <= 8'd0;
            // Initialize internal array
            merged_arr[0] <= 8'd0; merged_arr[1] <= 8'd0; merged_arr[2] <= 8'd0; merged_arr[3] <= 8'd0;
            merged_arr[4] <= 8'd0; merged_arr[5] <= 8'd0; merged_arr[6] <= 8'd0; merged_arr[7] <= 8'd0;
            merged_arr[8] <= 8'd0; merged_arr[9] <= 8'd0; merged_arr[10] <= 8'd0; merged_arr[11] <= 8'd0;
            merged_arr[12] <= 8'd0; merged_arr[13] <= 8'd0; merged_arr[14] <= 8'd0; merged_arr[15] <= 8'd0;
            merged_arr[16] <= 8'd0; merged_arr[17] <= 8'd0; merged_arr[18] <= 8'd0; merged_arr[19] <= 8'd0;
            merged_arr[20] <= 8'd0; merged_arr[21] <= 8'd0; merged_arr[22] <= 8'd0; merged_arr[23] <= 8'd0;
            merged_arr[24] <= 8'd0; merged_arr[25] <= 8'd0; merged_arr[26] <= 8'd0; merged_arr[27] <= 8'd0;
            merged_arr[28] <= 8'd0; merged_arr[29] <= 8'd0; merged_arr[30] <= 8'd0; merged_arr[31] <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            if (start) begin
                // Initialize on start
                i <= 5'd0;
                j <= 5'd0;
                d <= 5'd0;
                copy_ptr <= 5'd0;
                k_index <= k - 5'd1;  // Convert 1-indexed to 0-indexed
                arr1_done <= 1'b0;
                arr2_done <= 1'b0;
                fetch_pending <= 1'b0;
                cycle_count <= 8'd0;
            end
            
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                FETCH: begin
                    // Set addresses for next cycle
                    if (!arr1_done && i < arr1_len) begin
                        arr1_addr <= i;
                    end else begin
                        arr1_addr <= 4'd0;
                    end
                    
                    if (!arr2_done && j < arr2_len) begin
                        arr2_addr <= j;
                    end else begin
                        arr2_addr <= 4'd0;
                    end
                    
                    // Advance fetch pending flag
                    fetch_pending <= 1'b1;
                end
                
                COMPARE: begin
                    // Load fetched values into temp registers
                    if (fetch_pending) begin
                        if (!arr1_done && i < arr1_len)
                            temp_arr1 <= arr1_in;
                        else
                            temp_arr1 <= 8'hFF;  // Max value when done
                        
                        if (!arr2_done && j < arr2_len)
                            temp_arr2 <= arr2_in;
                        else
                            temp_arr2 <= 8'hFF;  // Max value when done
                    end
                    fetch_pending <= 1'b0;
                    
                    // Update done flags
                    if (i >= arr1_len)
                        arr1_done <= 1'b1;
                    if (j >= arr2_len)
                        arr2_done <= 1'b1;
                end
                
                MERGE: begin
                    // Store smaller element
                    if (temp_arr1 <= temp_arr2) begin
                        merged_arr[d] <= temp_arr1;
                        if (!arr1_done)
                            i <= i + 5'd1;
                    end else begin
                        merged_arr[d] <= temp_arr2;
                        if (!arr2_done)
                            j <= j + 5'd1;
                    end
                    d <= d + 5'd1;
                end
                
                COMPLETE: begin
                    // Read kth element from internal array
                    result <= merged_arr[copy_ptr];
                    if (copy_ptr == k_index) begin
                        done <= 1'b1;
                    end
                    copy_ptr <= copy_ptr + 5'd1;
                end
                
                default: begin
                    // IDLE state - all signals already initialized
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule