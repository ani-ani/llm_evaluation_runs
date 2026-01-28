module SharedNumberSolver (
    input clk,
    input rst_n,
    input start,
    input [47:0] p1_in,
    input [47:0] p2_in,
    input [3:0] n,
    input [3:0] m,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] PARSE_P1   = 4'd1;
    localparam [3:0] PARSE_P2   = 4'd2;
    localparam [3:0] COMPARE    = 4'd3;
    localparam [3:0] CALCULATE  = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Storage for parsed pairs
    reg [3:0] p1_pairs_num0 [0:11]; // 12 pairs
    reg [3:0] p1_pairs_num1 [0:11]; // 12 pairs
    reg [3:0] p2_pairs_num0 [0:11]; // 12 pairs
    reg [3:0] p2_pairs_num1 [0:11]; // 12 pairs
    
    // Counters
    reg [3:0] p1_idx;
    reg [3:0] p2_idx;
    reg [3:0] parse_cnt;
    
    // Results storage and flags
    reg [3:0] shared_numbers [0:9]; // Track 1-9 (0 unused)
    reg shared_valid [0:9];
    reg [3:0] num_unique_shares;
    reg [3:0] p1_common [0:11]; // Stores common number for each p1 pair (or F if none/multiple)
    reg [3:0] p2_common [0:11]; // Stores common number for each p2 pair (or F if none/multiple)
    reg all_p1_same;
    reg all_p2_same;
    reg [3:0] common_val_p1;
    reg [3:0] common_val_p2;
    
    // Temporary comparison registers
    reg [3:0] cur_p1_num0;
    reg [3:0] cur_p1_num1;
    reg [3:0] cur_p2_num0;
    reg [3:0] cur_p2_num1;
    reg [3:0] intersection_size;
    reg [3:0] intersection_val;
    reg [3:0] temp_common;
    integer i;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            p1_idx <= 4'd0;
            p2_idx <= 4'd0;
            parse_cnt <= 4'd0;
            num_unique_shares <= 4'd0;
            all_p1_same <= 1'b0;
            all_p2_same <= 1'b0;
            common_val_p1 <= 4'd0;
            common_val_p2 <= 4'd0;
            cur_p1_num0 <= 4'd0;
            cur_p1_num1 <= 4'd0;
            cur_p2_num0 <= 4'd0;
            cur_p2_num1 <= 4'd0;
            intersection_size <= 4'd0;
            intersection_val <= 4'd0;
            temp_common <= 4'd0;
            
            // Initialize arrays to 0
            for (i = 0; i < 12; i = i + 1) begin
                p1_pairs_num0[i] <= 4'd0;
                p1_pairs_num1[i] <= 4'd0;
                p2_pairs_num0[i] <= 4'd0;
                p2_pairs_num1[i] <= 4'd0;
                p1_common[i] <= 4'd0;
                p2_common[i] <= 4'd0;
            end
            for (i = 0; i < 10; i = i + 1) begin
                shared_numbers[i] <= 4'd0;
                shared_valid[i] <= 1'b0;
            end
            
        end else begin
            // Default assignments
            done <= 1'b0;
            if (state != IDLE) cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize parsing
                        parse_cnt <= 4'd0;
                        // Initialize unique shares count
                        num_unique_shares <= 4'd0;
                        // Initialize common flags
                        all_p1_same <= 1'b1;
                        all_p2_same <= 1'b1;
                        common_val_p1 <= 4'd0;
                        common_val_p2 <= 4'd0;
                        // Reset array flags
                        for (i = 0; i < 10; i = i + 1) begin
                            shared_valid[i] <= 1'b0;
                        end
                        for (i = 0; i < 12; i = i + 1) begin
                            p1_common[i] <= 4'dF;
                            p2_common[i] <= 4'dF;
                        end
                    end
                end
                
                PARSE_P1: begin
                    if (parse_cnt < n) begin
                        // Extract numbers from p1_in
                        // Bit indices: [47:44] is pair 0, num 0; [43:40] is pair 0, num 1
                        // Pair i: bits [47-4*i:35-4*i] for num0, [43-4*i:39-4*i] for num1
                        p1_pairs_num0[parse_cnt] <= p1_in[(47 - 4*parse_cnt)*4 + 3 -: 4];
                        p1_pairs_num1[parse_cnt] <= p1_in[(43 - 4*parse_cnt)*4 + 3 -: 4];
                        parse_cnt <= parse_cnt + 4'd1;
                    end
                end
                
                PARSE_P2: begin
                    if (parse_cnt < m) begin
                        // Extract numbers from p2_in
                        p2_pairs_num0[parse_cnt] <= p2_in[(47 - 4*parse_cnt)*4 + 3 -: 4];
                        p2_pairs_num1[parse_cnt] <= p2_in[(43 - 4*parse_cnt)*4 + 3 -: 4];
                        parse_cnt <= parse_cnt + 4'd1;
                    end
                end
                
                COMPARE: begin
                    // Compare all pairs (p1_idx from 0 to n-1, p2_idx from 0 to m-1)
                    if (p1_idx < n && p2_idx < m) begin
                        // Calculate intersection size and value
                        cur_p1_num0 <= p1_pairs_num0[p1_idx];
                        cur_p1_num1 <= p1_pairs_num1[p1_idx];
                        cur_p2_num0 <= p2_pairs_num0[p2_idx];
                        cur_p2_num1 <= p2_pairs_num1[p2_idx];
                        
                        intersection_size <= 4'd0;
                        intersection_val <= 4'd0;
                        
                        // Manual intersection check (unrolled)
                        // Check p1_num0 against both p2 nums
                        if (p1_pairs_num0[p1_idx] == p2_pairs_num0[p2_idx] || p1_pairs_num0[p1_idx] == p2_pairs_num1[p2_idx]) begin
                            intersection_size <= intersection_size + 4'd1;
                            intersection_val <= p1_pairs_num0[p1_idx];
                        end
                        // Check p1_num1 against both p2 nums (only if p1_num0 wasn't a match or matches different)
                        if (p1_pairs_num1[p1_idx] == p2_pairs_num0[p2_idx] || p1_pairs_num1[p1_idx] == p2_pairs_num1[p2_idx]) begin
                            if (intersection_size == 4'd0) begin
                                intersection_size <= 4'd1;
                                intersection_val <= p1_pairs_num1[p1_idx];
                            end else if (p1_pairs_num1[p1_idx] != intersection_val) begin
                                intersection_size <= intersection_size + 4'd1;
                            end
                        end
                        
                        // Update counters for next iteration
                        if (p2_idx == m - 4'd1) begin
                            p2_idx <= 4'd0;
                            if (p1_idx == n - 4'd1) begin
                                // Done with all comparisons, proceed to processing
                                // (handled in CALCULATE state)
                            end else begin
                                p1_idx <= p1_idx + 4'd1;
                            end
                        end else begin
                            p2_idx <= p2_idx + 4'd1;
                        end
                    end
                end
                
                CALCULATE: begin
                    // Process comparison results (stored in temp variables from previous cycle)
                    if (p1_idx < n && p2_idx < m) begin
                        // Check if intersection found
                        if (intersection_size == 4'd1) begin
                            // Record shared number
                            if (intersection_val >= 4'd1 && intersection_val <= 4'd9) begin
                                if (!shared_valid[intersection_val]) begin
                                    shared_valid[intersection_val] <= 1'b1;
                                    shared_numbers[intersection_val] <= intersection_val;
                                    num_unique_shares <= num_unique_shares + 4'd1;
                                end
                            end
                            
                            // Update p1_common
                            if (p1_common[p1_idx] == 4'dF) begin
                                p1_common[p1_idx] <= intersection_val;
                            end else if (p1_common[p1_idx] != intersection_val) begin
                                p1_common[p1_idx] <= 4'dF; // Multiple different shares
                            end
                            
                            // Update p2_common
                            if (p2_common[p2_idx] == 4'dF) begin
                                p2_common[p2_idx] <= intersection_val;
                            end else if (p2_common[p2_idx] != intersection_val) begin
                                p2_common[p2_idx] <= 4'dF; // Multiple different shares
                            end
                        end
                        
                        // Move to next comparison pair
                        if (p2_idx == m - 4'd1) begin
                            p2_idx <= 4'd0;
                            if (p1_idx == n - 4'd1) begin
                                p1_idx <= 4'd0; // Reset for checking all_p1_same
                            end else begin
                                p1_idx <= p1_idx + 4'd1;
                            end
                        end else begin
                            p2_idx <= p2_idx + 4'd1;
                        end
                    end else if (p1_idx < n) begin
                        // Check if all p1 pairs have same common number
                        if (p1_common[p1_idx] == 4'dF || (common_val_p1 != 4'd0 && p1_common[p1_idx] != common_val_p1)) begin
                            all_p1_same <= 1'b0;
                        end else begin
                            if (common_val_p1 == 4'd0) begin
                                common_val_p1 <= p1_common[p1_idx];
                            end
                        end
                        p1_idx <= p1_idx + 4'd1;
                    end else if (p2_idx < m) begin
                        // Check if all p2 pairs have same common number
                        if (p2_common[p2_idx] == 4'dF || (common_val_p2 != 4'd0 && p2_common[p2_idx] != common_val_p2)) begin
                            all_p2_same <= 1'b0;
                        end else begin
                            if (common_val_p2 == 4'd0) begin
                                common_val_p2 <= p2_common[p2_idx];
                            end
                        end
                        p2_idx <= p2_idx + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    // Determine result
                    if (num_unique_shares == 4'd1) begin
                        // Case 1: Exactly one unique shared number
                        for (i = 1; i < 10; i = i + 1) begin
                            if (shared_valid[i]) begin
                                result <= i[3:0];
                            end
                        end
                    end else if (all_p1_same && all_p2_same && num_unique_shares > 4'd1) begin
                        // Case 2: Multiple shared numbers but consistent within each participant
                        result <= 4'd0;
                    end else begin
                        // Case 3: Otherwise
                        result <= 4'b1111; // -1
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE_P1;
            end
            PARSE_P1: begin
                if (parse_cnt >= n) next_state = PARSE_P2;
            end
            PARSE_P2: begin
                if (parse_cnt >= m) next_state = COMPARE;
            end
            COMPARE: begin
                // Wait for comparison to complete
                // We need to wait until we have processed all pairs
                // This is a bit tricky in one cycle, we use CALCULATE state
                if (p1_idx >= n && p2_idx >= m) next_state = CALCULATE;
            end
            CALCULATE: begin
                // Process all pairs and then check consistency
                if (p1_idx >= n && p2_idx >= m) next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = DONE_STATE;
        end
    end

endmodule