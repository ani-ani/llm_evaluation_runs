module FindCommonElements(
    input clk,
    input rst_n,
    input start,
    input list_valid,
    input [2:0] sublist_len,
    input [7:0] sublist_data,
    input [2:0] sublist_idx,
    output reg [15:0][7:0] common,
    output reg [4:0] common_count,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] FIND_CANDIDATES = 3'd2;
    localparam [2:0] VERIFY = 3'd3;
    localparam [2:0] OUTPUT_RESULTS = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    localparam [2:0] ERROR_STATE = 3'd6;

    // Internal storage for sublists
    // Sublist memory: 8 sublists x 16 elements x 8 bits = 1024 bytes
    // Using 2D array for sublists storage
    reg [7:0] sublist_storage [0:7][0:15];
    reg [3:0] sublist_lengths [0:7];  // Store lengths for each sublist
    
    // Valid flags for each sublist
    reg [7:0] sublist_valid_flag;
    
    // FSM state registers
    reg [2:0] state, next_state;
    
    // Internal counters and pointers
    reg [2:0] sublist_idx_reg;  // Current sublist being loaded or checked
    reg [3:0] elem_idx;         // Element index within current sublist
    reg [2:0] sublist_count;    // Number of sublists loaded
    reg [4:0] total_elems;      // Total elements across all sublists
    
    // For finding candidates
    reg [7:0] candidate;        // Current candidate element from first sublist
    reg [4:0] candidate_idx;    // Index in first sublist
    reg [4:0] output_count;     // Output buffer counter
    
    // For verification
    reg [2:0] verify_sublist;   // Which sublist we're verifying against
    reg [7:0] compare_element;  // Element to compare
    reg is_common;              // Flag if element is common to all
    
    // Cycle counter to prevent infinite loops
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd512;
    
    // Error detection
    reg error_internal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            sublist_idx_reg <= 3'd0;
            elem_idx <= 4'd0;
            sublist_count <= 3'd0;
            total_elems <= 5'd0;
            candidate_idx <= 5'd0;
            output_count <= 5'd0;
            verify_sublist <= 3'd0;
            candidate <= 8'd0;
            compare_element <= 8'd0;
            is_common <= 1'b0;
            cycle_count <= 9'd0;
            error_internal <= 1'b0;
            
            // Outputs
            common_count <= 5'd0;
            done <= 1'b0;
            error <= 1'b0;
            sublist_valid_flag <= 8'd0;
            
            // Initialize all storage elements to 0
            begin : reset_loop
                integer i, j;
                for (i = 0; i < 8; i = i + 1) begin
                    sublist_lengths[i] <= 4'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        sublist_storage[i][j] <= 8'd0;
                    end
                end
            end
            
            // Clear output array
            begin : clear_output
                integer k;
                for (k = 0; k < 16; k = k + 1) begin
                    common[k] <= 8'd0;
                end
            end
            
        end else begin
            done <= 1'b0;
            error <= 1'b0;
            
            case (state)
                IDLE: begin
                    sublist_idx_reg <= 3'd0;
                    elem_idx <= 4'd0;
                    sublist_count <= 3'd0;
                    total_elems <= 5'd0;
                    candidate_idx <= 5'd0;
                    output_count <= 5'd0;
                    verify_sublist <= 3'd0;
                    cycle_count <= 9'd0;
                    error_internal <= 1'b0;
                    
                    begin : clear_output_idle
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            common[k] <= 8'd0;
                        end
                        common_count <= 5'd0;
                    end
                    
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (list_valid) begin
                        // Store current element
                        if (sublist_len > 4'd8) begin
                            // Error: sublist length > 8
                            error_internal <= 1'b1;
                            state <= ERROR_STATE;
                        end else if (elem_idx < sublist_len) begin
                            // Valid element to store
                            if (sublist_idx > 3'd7) begin
                                // Error: sublist index > 7
                                error_internal <= 1'b1;
                                state <= ERROR_STATE;
                            end else begin
                                sublist_storage[sublist_idx][elem_idx] <= sublist_data;
                                elem_idx <= elem_idx + 4'd1;
                            end
                        end
                        
                        // Update total elements count
                        total_elems <= total_elems + 5'd1;
                        
                        // Check if we need to finalize this sublist
                        if (elem_idx >= sublist_len) begin
                            // This sublist is complete
                            if (sublist_len > 4'd0) begin
                                if (~sublist_valid_flag[sublist_idx]) begin
                                    sublist_valid_flag[sublist_idx] <= 1'b1;
                                    sublist_lengths[sublist_idx] <= sublist_len;
                                    sublist_count <= sublist_count + 3'd1;
                                end
                            end
                            elem_idx <= 4'd0;
                            
                            // Check if we have enough sublists (need at least 2 for intersection)
                            if (sublist_count >= 3'd2) begin
                                state <= FIND_CANDIDATES;
                            end else if (sublist_count == 3'd1) begin
                                // Only one sublist - all its elements are "common"
                                state <= OUTPUT_RESULTS;
                            end
                        end
                    end else begin
                        // No valid data, check if we're done loading
                        if (total_elems > 5'd0) begin
                            if (sublist_count >= 3'd2) begin
                                state <= FIND_CANDIDATES;
                            end else if (sublist_count == 3'd1) begin
                                state <= OUTPUT_RESULTS;
                            end else begin
                                // No data loaded, return to IDLE
                                state <= IDLE;
                            end
                        end
                    end
                    
                    cycle_count <= cycle_count + 9'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        error_internal <= 1'b1;
                        state <= ERROR_STATE;
                    end
                end
                
                FIND_CANDIDATES: begin
                    // Process first sublist elements as candidates
                    // Get next candidate from first valid sublist
                    if (candidate_idx < sublist_lengths[3'd0]) begin
                        candidate <= sublist_storage[3'd0][candidate_idx[3:0]];
                        compare_element <= sublist_storage[3'd0][candidate_idx[3:0]];
                        verify_sublist <= 3'd1;  // Start verifying against sublist 1
                        is_common <= 1'b1;        // Assume common until proven otherwise
                        state <= VERIFY;
                        candidate_idx <= candidate_idx + 5'd1;
                    end else begin
                        // No more candidates, done
                        common_count <= output_count;
                        state <= FINISH;
                    end
                    
                    cycle_count <= cycle_count + 9'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        error_internal <= 1'b1;
                        state <= ERROR_STATE;
                    end
                end
                
                VERIFY: begin
                    // Check if current candidate exists in all other sublists
                    if (verify_sublist < 3'd8) begin
                        if (sublist_valid_flag[verify_sublist]) begin
                            // This sublist is valid, check for element
                            reg found;
                            integer j;
                            found = 1'b0;
                            
                            // Search through current sublist elements
                            for (j = 0; j < 16; j = j + 1) begin
                                if (j < sublist_lengths[verify_sublist] && 
                                    sublist_storage[verify_sublist][j] == compare_element) begin
                                    found = 1'b1;
                                end
                            end
                            
                            if (!found) begin
                                is_common <= 1'b0;
                            end
                            
                            verify_sublist <= verify_sublist + 3'd1;
                        end else begin
                            // Skip invalid sublists
                            verify_sublist <= verify_sublist + 3'd1;
                        end
                    end else begin
                        // Finished checking all sublists
                        if (is_common && output_count < 5'd16) begin
                            // Add to output
                            common[output_count] <= compare_element;
                            output_count <= output_count + 5'd1;
                        end
                        state <= FIND_CANDIDATES;
                    end
                    
                    cycle_count <= cycle_count + 9'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        error_internal <= 1'b1;
                        state <= ERROR_STATE;
                    end
                end
                
                OUTPUT_RESULTS: begin
                    // Special case: only one sublist loaded
                    // All its elements are common (intersection of one set is itself)
                    if (output_count < sublist_lengths[3'd0]) begin
                        common[output_count] <= sublist_storage[3'd0][output_count[3:0]];
                        output_count <= output_count + 5'd1;
                    end else begin
                        common_count <= output_count;
                        state <= FINISH;
                    end
                    
                    cycle_count <= cycle_count + 9'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        error_internal <= 1'b1;
                        state <= ERROR_STATE;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    error <= error_internal;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
                    done <= 1'b1;
                    error <= 1'b1;
                    common_count <= 5'd0;
                    // Clear output
                    begin : clear_output_error
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            common[k] <= 8'd0;
                        end
                    end
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule