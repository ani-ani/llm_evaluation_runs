module nested_list_intersection(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Internal memory for sublists (8 sublists, 16 elements each, 8-bit)
    reg [7:0] sublist_mem [0:7][0:15];
    reg [2:0] sublist_count;
    reg [3:0] elem_count [0:7];
    
    // Processing variables
    reg [2:0] current_sublist;
    reg [3:0] current_elem;
    reg [2:0] compare_sublist;
    reg [3:0] compare_elem;
    reg [3:0] common_idx;
    reg [7:0] current_value;
    reg found;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            common_count <= 5'd0;
            sublist_count <= 3'd0;
            cycle_count <= 8'd0;
            
            // Initialize common array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                common[i] <= 8'd0;
            end
            
            // Initialize sublist memory and counters
            integer j, k;
            for (j = 0; j < 8; j = j + 1) begin
                elem_count[j] <= 4'd0;
                for (k = 0; k < 16; k = k + 1) begin
                    sublist_mem[j][k] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                if (list_valid) begin
                    // Check for errors
                    if (sublist_idx >= 3'd8 || sublist_len > 3'd16) begin
                        next_state = IDLE;
                        error = 1'b1;
                    end else begin
                        next_state = LOAD;
                        error = 1'b0;
                    end
                end else begin
                    // Check if we have at least 2 sublists
                    if (sublist_count >= 2) begin
                        next_state = PROCESS;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            
            PROCESS: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end else if (current_sublist == sublist_count - 1 && 
                           current_elem == elem_count[current_sublist] - 1) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load sublist data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in reset
        end else begin
            if (state == LOAD && list_valid) begin
                // Store the element
                sublist_mem[sublist_idx][elem_count[sublist_idx]] <= sublist_data;
                elem_count[sublist_idx] <= elem_count[sublist_idx] + 1'b1;
                
                // Update sublist count if this is the first element of a new sublist
                if (elem_count[sublist_idx] == 1'b1) begin
                    sublist_count <= sublist_count + 1'b1;
                end
            end
        end
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in reset
        end else begin
            if (state == PROCESS) begin
                cycle_count <= cycle_count + 8'd1;
                
                // Get current value to check
                if (current_elem == 0) begin
                    current_value <= sublist_mem[current_sublist][current_elem];
                end
                
                // Compare with all other sublists
                if (compare_sublist == current_sublist) begin
                    // Skip comparing with same sublist
                    if (compare_elem == elem_count[compare_sublist] - 1) begin
                        compare_sublist <= compare_sublist + 1'b1;
                        compare_elem <= 0;
                    end else begin
                        compare_elem <= compare_elem + 1'b1;
                    end
                end else begin
                    // Check if value exists in this sublist
                    if (sublist_mem[compare_sublist][compare_elem] == current_value) begin
                        found <= 1'b1;
                        
                        // Move to next element in current sublist
                        if (current_elem == elem_count[current_sublist] - 1) begin
                            current_sublist <= current_sublist + 1'b1;
                            current_elem <= 0;
                        end else begin
                            current_elem <= current_elem + 1'b1;
                        end
                        
                        // Reset comparison pointers
                        compare_sublist <= 0;
                        compare_elem <= 0;
                    end else begin
                        if (compare_elem == elem_count[compare_sublist] - 1) begin
                            compare_sublist <= compare_sublist + 1'b1;
                            compare_elem <= 0;
                        end else begin
                            compare_elem <= compare_elem + 1'b1;
                        end
                    end
                end
                
                // If found in all sublists, add to common array
                if (found && compare_sublist == sublist_count) begin
                    // Check if already in common array
                    reg duplicate;
                    integer i;
                    duplicate = 1'b0;
                    for (i = 0; i < common_count; i = i + 1) begin
                        if (common[i] == current_value) begin
                            duplicate = 1'b1;
                        end
                    end
                    
                    if (!duplicate && common_count < 5'd16) begin
                        common[common_count] <= current_value;
                        common_count <= common_count + 1'b1;
                    end
                    
                    found <= 1'b0;
                    
                    // Move to next element
                    if (current_elem == elem_count[current_sublist] - 1) begin
                        current_sublist <= current_sublist + 1'b1;
                        current_elem <= 0;
                    end else begin
                        current_elem <= current_elem + 1'b1;
                    end
                    
                    // Reset comparison pointers
                    compare_sublist <= 0;
                    compare_elem <= 0;
                end
            end
        end
    end

    // Output state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == OUTPUT) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Initialize processing pointers at start of processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_sublist <= 3'd0;
            current_elem <= 4'd0;
            compare_sublist <= 3'd0;
            compare_elem <= 4'd0;
            common_idx <= 4'd0;
            found <= 1'b0;
        end else begin
            if (state == PROCESS && cycle_count == 1) begin
                current_sublist <= 3'd0;
                current_elem <= 4'd0;
                compare_sublist <= 3'd0;
                compare_elem <= 4'd0;
                common_idx <= 4'd0;
                found <= 1'b0;
            end
        end
    end

endmodule