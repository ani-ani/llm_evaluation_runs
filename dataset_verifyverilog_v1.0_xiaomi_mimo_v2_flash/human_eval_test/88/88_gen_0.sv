module conditional_sorter (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD          = 3'd1;
    localparam [2:0] CHECK_SUM     = 3'd2;
    localparam [2:0] SORT_INIT     = 3'd3;
    localparam [2:0] SORT_COMPARE  = 3'd4;
    localparam [2:0] SORT_SWAP     = 3'd5;
    localparam [2:0] OUTPUT_STATE  = 3'd6;
    localparam [2:0] DONE_STATE    = 3'd7;

    reg [2:0] state, next_state;
    
    // Internal registers for array processing
    reg [7:0] buffer [0:7];
    reg [7:0] temp_storage;
    reg [7:0] element_a;
    reg [7:0] element_b;
    
    // Sorting control variables
    reg [2:0] i;      // Outer loop index (0 to 7)
    reg [2:0] j;      // Inner loop index (0 to 6)
    reg [2:0] swap_count;  // Track swaps to optimize
    reg sort_direction;    // 0 = ascending, 1 = descending
    reg should_swap;       // Comparison result
    
    // Sum calculation
    reg [8:0] sum;  // 9-bit to prevent overflow
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;
    
    integer idx;  // For initialization loop

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            swap_count <= 3'd0;
            sum <= 9'd0;
            sort_direction <= 1'b0;
            should_swap <= 1'b0;
            element_a <= 8'd0;
            element_b <= 8'd0;
            temp_storage <= 8'd0;
            // Initialize result array
            for (idx = 0; idx < 8; idx = idx + 1) begin
                result[idx] <= 8'd0;
                buffer[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load input array into buffer
                    buffer[0] <= arr[0];
                    buffer[1] <= arr[1];
                    buffer[2] <= arr[2];
                    buffer[3] <= arr[3];
                    buffer[4] <= arr[4];
                    buffer[5] <= arr[5];
                    buffer[6] <= arr[6];
                    buffer[7] <= arr[7];
                    state <= CHECK_SUM;
                end
                
                CHECK_SUM: begin
                    // Calculate sum of first and last elements
                    sum <= {1'b0, buffer[0]} + {1'b0, buffer[7]};
                    state <= SORT_INIT;
                end
                
                SORT_INIT: begin
                    // Determine sort direction
                    sort_direction <= sum[0];  // 1 if odd (ascending), 0 if even (descending)
                    i <= 3'd0;
                    j <= 3'd0;
                    swap_count <= 3'd0;
                    state <= SORT_COMPARE;
                end
                
                SORT_COMPARE: begin
                    // Compare elements at j and j+1
                    element_a <= buffer[j];
                    element_b <= buffer[j + 1];
                    
                    // Determine if swap needed based on direction
                    // Ascending (sort_direction=1): swap if element_a > element_b
                    // Descending (sort_direction=0): swap if element_a < element_b
                    if (sort_direction) begin
                        should_swap <= (element_a > element_b);
                    end else begin
                        should_swap <= (element_a < element_b);
                    end
                    
                    state <= SORT_SWAP;
                end
                
                SORT_SWAP: begin
                    if (should_swap) begin
                        // Swap elements
                        buffer[j] <= element_b;
                        buffer[j + 1] <= element_a;
                        swap_count <= swap_count + 3'd1;
                    end
                    
                    // Move to next inner loop iteration
                    if (j < 3'd6) begin
                        j <= j + 3'd1;
                        state <= SORT_COMPARE;
                    end else begin
                        // End of inner loop, check if we need another pass
                        if (i < 3'd7 && swap_count > 3'd0) begin
                            i <= i + 3'd1;
                            j <= 3'd0;
                            swap_count <= 3'd0;
                            state <= SORT_COMPARE;
                        end else begin
                            // Sorting complete or no swaps in last pass
                            state <= OUTPUT_STATE;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    cycle_count <= cycle_count + 8'd1;
                end
                
                OUTPUT_STATE: begin
                    // Copy sorted buffer to output
                    result[0] <= buffer[0];
                    result[1] <= buffer[1];
                    result[2] <= buffer[2];
                    result[3] <= buffer[3];
                    result[4] <= buffer[4];
                    result[5] <= buffer[5];
                    result[6] <= buffer[6];
                    result[7] <= buffer[7];
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (state != IDLE && cycle_count >= MAX_CYCLES) begin
                state <= OUTPUT_STATE;
            end
        end
    end

endmodule