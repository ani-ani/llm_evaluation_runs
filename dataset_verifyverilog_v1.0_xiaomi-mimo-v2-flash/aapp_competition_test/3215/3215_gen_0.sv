module riffle_shuffle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] card_in,
    input wire valid_in,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done,
    output reg idle
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] CHECK_SORTED = 3'd2;
    localparam [2:0] FIND_CYCLES = 3'd3;
    localparam [2:0] CALC_RESULT = 3'd4;
    localparam [2:0] OUTPUT      = 3'd5;
    
    reg [2:0] state;
    reg [3:0] n; // Number of cards (1-16)
    reg [3:0] idx; // Current index for processing
    reg [3:0] max_cycle_len; // Maximum cycle length found
    reg [3:0] current_len; // Current cycle length being tracked
    reg [3:0] visited_mask; // Bitmask of visited positions
    reg [15:0] permutation [0:15]; // Store permutation values
    reg [3:0] cycle_count; // Counter for cycles
    reg [3:0] bit_pos; // For bit length calculation
    reg found_unsorted; // Flag for sorted check
    
    // Temporary registers for processing
    reg [3:0] temp_idx;
    reg [3:0] start_idx;
    reg [3:0] current_pos;
    reg [3:0] next_pos;
    reg [3:0] search_count;
    
    // Helper function to find cycle length
    function automatic [3:0] find_cycle_length;
        input [3:0] start;
        input [15:0] perm [0:15];
        input [3:0] size;
        begin
            reg [3:0] len;
            reg [3:0] pos;
            reg [3:0] visited;
            len = 4'd0;
            visited = 4'd0;
            pos = start;
            // Trace cycle
            while (len < size && visited[pos] == 1'b0) begin
                visited[pos] = 1'b1;
                // Find position of current value
                for (int i = 0; i < size; i = i + 1) begin
                    if (perm[i] == (pos + 1)) begin // Values are 1-indexed
                        pos = i;
                        break;
                    end
                end
                len = len + 1'd1;
            end
            find_cycle_length = len;
        end
    endfunction
    
    // Helper to check if array is sorted
    function automatic is_sorted;
        input [15:0] perm [0:15];
        input [3:0] size;
        begin
            reg [3:0] i;
            is_sorted = 1'b1;
            for (i = 1; i < size; i = i + 1) begin
                if (perm[i] != i + 1) begin
                    is_sorted = 1'b0;
                end
            end
            // Also check first element
            if (perm[0] != 1) begin
                is_sorted = 1'b0;
            end
        end
    endfunction
    
    // Helper to find bit length
    function automatic [3:0] bit_length;
        input [3:0] value;
        begin
            reg [3:0] bits;
            reg [3:0] v;
            bits = 4'd0;
            v = value;
            while (v > 0) begin
                v = v >> 1;
                bits = bits + 1'd1;
            end
            bit_length = bits;
        end
    endfunction
    
    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idle <= 1'b1;
            n <= 4'd0;
            idx <= 4'd0;
            max_cycle_len <= 4'd0;
            current_len <= 4'd0;
            visited_mask <= 4'd0;
            cycle_count <= 4'd0;
            bit_pos <= 4'd0;
            found_unsorted <= 1'b0;
            temp_idx <= 4'd0;
            start_idx <= 4'd0;
            current_pos <= 4'd0;
            next_pos <= 4'd0;
            search_count <= 4'd0;
            // Initialize permutation array
            for (int i = 0; i < 16; i = i + 1) begin
                permutation[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idle <= 1'b1;
                    if (start) begin
                        n <= len;
                        idx <= 4'd0;
                        state <= LOAD;
                        idle <= 1'b0;
                        // Reset permutation
                        for (int i = 0; i < 16; i = i + 1) begin
                            permutation[i] <= 16'd0;
                        end
                    end
                end
                
                LOAD: begin
                    if (valid_in && idx < n) begin
                        permutation[idx] <= card_in;
                        idx <= idx + 1'd1;
                    end
                    if (idx >= n) begin
                        idx <= 4'd0;
                        state <= CHECK_SORTED;
                    end
                end
                
                CHECK_SORTED: begin
                    found_unsorted <= 1'b0;
                    // Check if sorted (1,2,3,...,n)
                    if (permutation[0] != 1) begin
                        found_unsorted <= 1'b1;
                    end
                    for (int i = 1; i < 16; i = i + 1) begin
                        if (i < n) begin
                            if (permutation[i] != i + 1) begin
                                found_unsorted <= 1'b1;
                            end
                        end
                    end
                    
                    if (found_unsorted == 1'b0) begin
                        // Already sorted
                        result <= 4'd0;
                        state <= OUTPUT;
                    end else begin
                        // Need to process
                        max_cycle_len <= 4'd0;
                        visited_mask <= 4'd0;
                        idx <= 4'd0;
                        state <= FIND_CYCLES;
                    end
                end
                
                FIND_CYCLES: begin
                    // Find next unvisited index
                    while (idx < n && visited_mask[idx]) begin
                        idx <= idx + 1'd1;
                    end
                    
                    if (idx < n) begin
                        // Start new cycle
                        temp_idx <= idx;
                        current_pos <= idx;
                        current_len <= 4'd1;
                        visited_mask[idx] <= 1'b1;
                        search_count <= 4'd0;
                        // Need to find where current_pos+1 is located
                        // Start search from temp_idx
                        start_idx <= 4'd0;
                        state <= FIND_CYCLES; // Stay in state
                        
                        // Find next position in cycle
                        for (int i = 0; i < 16; i = i + 1) begin
                            if (permutation[i] == idx + 1) begin
                                next_pos <= i;
                            end
                        end
                        
                        if (next_pos != temp_idx && visited_mask[next_pos] == 1'b0) begin
                            current_pos <= next_pos;
                            current_len <= current_len + 1'd1;
                            visited_mask[next_pos] <= 1'b1;
                            // Continue cycle
                            for (int i = 0; i < 16; i = i + 1) begin
                                if (permutation[i] == next_pos + 1) begin
                                    next_pos <= i;
                                end
                            end
                        end else begin
                            // Cycle complete
                            if (current_len > max_cycle_len) begin
                                max_cycle_len <= current_len;
                            end
                            idx <= idx + 1'd1;
                        end
                    end else begin
                        // All cycles processed
                        state <= CALC_RESULT;
                    end
                end
                
                CALC_RESULT: begin
                    // Calculate bit length of max_cycle_len
                    result <= 4'd0;
                    if (max_cycle_len > 0) begin
                        bit_pos <= 4'd0;
                        temp_idx <= max_cycle_len;
                        state <= OUTPUT;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational bit length calculation
    always @(*) begin
        if (state == CALC_RESULT && max_cycle_len > 0) begin
            reg [3:0] v;
            reg [3:0] bits;
            v = max_cycle_len;
            bits = 4'd0;
            while (v > 0) begin
                v = v >> 1;
                bits = bits + 1'd1;
            end
            result = bits;
        end
    end

endmodule