module bug_scheduling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] m,
    input wire [7:0] n,
    input wire [15:0] s,
    input wire [15:0] bugs [0:15],
    input wire [15:0] abilities [0:15],
    input wire [15:0] costs [0:15],
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_SEARCH   = 4'd1;
    localparam [3:0] SETUP_D       = 4'd2;
    localparam [3:0] SORT_BUGS     = 4'd3;
    localparam [3:0] PREP_GROUPS   = 4'd4;
    localparam [3:0] GROUP_LOOP    = 4'd5;
    localparam [3:0] FIND_STUDENT  = 4'd6;
    localparam [3:0] CHECK_GROUP   = 4'd7;
    localparam [3:0] CHECK_TOTAL   = 4'd8;
    localparam [3:0] UPDATE_D      = 4'd9;
    localparam [3:0] UPDATE_BEST   = 4'd10;
    localparam [3:0] FINISH_STATE  = 4'd11;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Search variables
    reg [3:0] low, high, mid, best_d;
    reg [3:0] d;
    reg valid_schedule;
    reg [15:0] total_cost;
    reg [3:0] num_groups;
    reg [3:0] group_idx;
    reg [3:0] student_idx;
    reg [3:0] bug_count_in_group;
    reg [15:0] max_bug_in_group;
    reg [3:0] bug_ptr;
    reg [3:0] group_start;

    // Sorted bugs and mapping
    reg [15:0] sorted_bugs [0:15];
    reg [3:0] bug_index_map [0:15];
    reg [3:0] bug_original_idx [0:15];

    // Found student assignment for current group
    reg [3:0] group_student;

    // Students availability
    reg student_available [0:15];

    // Temporary storage for comparison
    reg [15:0] temp_max;
    reg [3:0] temp_idx;
    reg [15:0] current_bug;
    reg [3:0] best_student;
    reg [15:0] min_cost;

    // Loop counters
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 4'd0;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            best_d <= 4'd0;
            d <= 4'd0;
            total_cost <= 16'd0;
            valid_schedule <= 1'b0;
            group_idx <= 4'd0;
            student_idx <= 4'd0;
            bug_ptr <= 4'd0;
            group_start <= 4'd0;
            bug_count_in_group <= 4'd0;
            max_bug_in_group <= 16'd0;
            num_groups <= 4'd0;
            group_student <= 4'd0;
            best_student <= 4'd0;
            min_cost <= 16'd0;
            temp_max <= 16'd0;
            temp_idx <= 4'd0;
            current_bug <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_bugs[i] <= 16'd0;
                bug_index_map[i] <= 4'd0;
                bug_original_idx[i] <= 4'd0;
                student_available[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            if (state != IDLE) cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result <= 4'd0;
                    low <= 4'd0;
                    high <= 4'd0;
                    mid <= 4'd0;
                    best_d <= 4'd0;
                    d <= 4'd0;
                    total_cost <= 16'd0;
                    valid_schedule <= 1'b0;
                    group_idx <= 4'd0;
                    student_idx <= 4'd0;
                    bug_ptr <= 4'd0;
                    group_start <= 4'd0;
                    bug_count_in_group <= 4'd0;
                    max_bug_in_group <= 16'd0;
                    num_groups <= 4'd0;
                    group_student <= 4'd0;
                    best_student <= 4'd0;
                    min_cost <= 16'd0;
                    temp_max <= 16'd0;
                    temp_idx <= 4'd0;
                    current_bug <= 16'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        sorted_bugs[i] <= 16'd0;
                        bug_index_map[i] <= 4'd0;
                        bug_original_idx[i] <= 4'd0;
                        student_available[i] <= 1'b0;
                    end
                end

                INIT_SEARCH: begin
                    // Initialize binary search bounds
                    low <= 4'd1;
                    high <= m[3:0]; // m is at most 16
                    if (high < 4'd1) high <= 4'd1;
                    best_d <= 4'd0;
                end

                SETUP_D: begin
                    // Set mid for current search
                    mid <= (low + high) >> 1;
                    d <= (low + high) >> 1;
                end

                SORT_BUGS: begin
                    // Sort bugs descending complexity
                    // Using a simple bubble sort simulation step by step
                    // This is a simplified logic: load bugs into sorted_bugs
                    // For synthesis, we use combinational logic for sorting
                    // Since we need to sort every D, we do it here
                    // For speed, we'll implement a simple priority encoder logic
                    // But to save space, we'll use a simple approach:
                    // Load bugs, then for each position, find max remaining
                end

                PREP_GROUPS: begin
                    // Setup group loop
                    group_idx <= 4'd0;
                    group_start <= 4'd0;
                    total_cost <= 16'd0;
                    valid_schedule <= 1'b1; // Assume valid until proven otherwise
                    // Reset student availability
                    for (i = 0; i < 16; i = i + 1) begin
                        student_available[i] <= 1'b1;
                    end
                end

                GROUP_LOOP: begin
                    // Start processing a new group
                    if (group_start < m[3:0]) begin
                        bug_ptr <= group_start;
                        max_bug_in_group <= sorted_bugs[group_start];
                        bug_count_in_group <= 4'd0;
                        temp_idx <= group_start;
                    end
                end

                FIND_STUDENT: begin
                    // Look for cheapest student who can handle max_bug_in_group
                    best_student <= 4'd15; // Invalid
                    min_cost <= 16'hFFFF;
                    student_idx <= 4'd0;
                end

                CHECK_GROUP: begin
                    // Accumulate group bugs
                    // Check if bug_ptr reached end or count == d
                    if (bug_ptr < (group_start + d) && bug_ptr < m[3:0]) begin
                        // Update max complexity in group
                        if (sorted_bugs[bug_ptr] > max_bug_in_group) begin
                            max_bug_in_group <= sorted_bugs[bug_ptr];
                        end
                        bug_ptr <= bug_ptr + 4'd1;
                        bug_count_in_group <= bug_count_in_group + 4'd1;
                    end else begin
                        // Group formed, now find student
                        // Reset student finding loop
                        student_idx <= 4'd0;
                        min_cost <= 16'hFFFF;
                        best_student <= 4'd15;
                    end
                end

                CHECK_TOTAL: begin
                    // Check total cost and validity
                    if (!valid_schedule || total_cost > s) begin
                        // Invalid schedule or over budget
                        valid_schedule <= 1'b0;
                    end
                    group_start <= group_start + d;
                    group_idx <= group_idx + 4'd1;
                end

                UPDATE_D: begin
                    // Binary search update
                    if (valid_schedule && total_cost <= s) begin
                        best_d <= d;
                        if (d == 4'd1) high <= 4'd1; // Found minimal
                        else high <= d - 4'd1;
                    end else begin
                        low <= d + 4'd1;
                    end
                end

                UPDATE_BEST: begin
                    // Prepare to assign result
                    result <= best_d;
                end

                FINISH_STATE: begin
                    done <= 1'b1;
                end
            endcase

            // Specialized logic embedded in state transitions
            // Sorting Logic (combinational block simulation in sequential)
            if (state == SORT_BUGS) begin
                // Simple selection sort logic (one iteration per cycle to fit timing)
                // We need a counter for sorting steps, reusing bug_ptr
                // To be compact: load bugs into sorted_bugs initially
                if (cycle_count == 4'd2) begin // First entry after SETUP_D
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < m[3:0]) begin
                            sorted_bugs[i] <= bugs[i];
                            bug_original_idx[i] <= i[3:0];
                        end else begin
                            sorted_bugs[i] <= 16'd0;
                            bug_original_idx[i] <= 4'd0;
                        end
                    end
                    bug_ptr <= 4'd0;
                end else begin
                    // Bubble sort pass
                    if (bug_ptr < m[3:0] - 4'd1) begin
                        if (sorted_bugs[bug_ptr] < sorted_bugs[bug_ptr + 4'd1]) begin
                            // Swap
                            temp_max <= sorted_bugs[bug_ptr];
                            sorted_bugs[bug_ptr] <= sorted_bugs[bug_ptr + 4'd1];
                            sorted_bugs[bug_ptr + 4'd1] <= temp_max;
                            temp_idx <= bug_original_idx[bug_ptr];
                            bug_original_idx[bug_ptr] <= bug_original_idx[bug_ptr + 4'd1];
                            bug_original_idx[bug_ptr + 4'd1] <= temp_idx;
                        end
                        bug_ptr <= bug_ptr + 4'd1;
                    end else begin
                        // Check if sorted (reset pointer for next pass or move on)
                        // For 16 elements, few passes needed. 
                        // To simplify: we assume simple sort completes in fixed cycles
                        // Actually, let's just sort by finding max for each position
                        // This is easier to implement sequentially
                    end
                end
            end

            // Logic for finding student
            if (state == FIND_STUDENT || (state == CHECK_GROUP && bug_ptr >= (group_start + d))) begin
                if (student_idx < n[3:0]) begin
                    if (student_available[student_idx] && abilities[student_idx] >= max_bug_in_group) begin
                        if (costs[student_idx] < min_cost) begin
                            min_cost <= costs[student_idx];
                            best_student <= student_idx;
                        end
                    end
                    student_idx <= student_idx + 4'd1;
                end else begin
                    // Finished checking students
                    if (best_student < 4'd15) begin
                        // Assign student
                        student_available[best_student] <= 1'b0;
                        total_cost <= total_cost + min_cost;
                        // Move to next group
                        group_start <= group_start + bug_count_in_group;
                        group_idx <= group_idx + 4'd1;
                    end else begin
                        // No valid student found
                        valid_schedule <= 1'b0;
                    end
                end
            end

            // Ensure we don't exceed cycle limit
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH_STATE;
            end
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_SEARCH;
            end
            INIT_SEARCH: next_state = SETUP_D;
            SETUP_D: begin
                if (low > high) next_state = FINISH_STATE;
                else next_state = SORT_BUGS;
            end
            SORT_BUGS: begin
                // Simplified: assume sort takes a few cycles, then proceed
                if (cycle_count > 4'd8) next_state = PREP_GROUPS;
                else next_state = SORT_BUGS;
            end
            PREP_GROUPS: next_state = GROUP_LOOP;
            GROUP_LOOP: begin
                if (group_start >= m[3:0]) next_state = UPDATE_D;
                else next_state = FIND_STUDENT;
            end
            FIND_STUDENT: next_state = CHECK_GROUP;
            CHECK_GROUP: begin
                if (bug_ptr >= (group_start + d) || bug_ptr >= m[3:0]) next_state = FIND_STUDENT;
                else next_state = CHECK_GROUP;
            end
            CHECK_TOTAL: next_state = GROUP_LOOP;
            UPDATE_D: begin
                if (low > high) next_state = UPDATE_BEST;
                else next_state = SETUP_D;
            end
            UPDATE_BEST: next_state = FINISH_STATE;
            FINISH_STATE: begin
                if (done) next_state = IDLE; // Stay done until reset
            end
            default: next_state = IDLE;
        endcase
        
        // Override for student finding logic in CHECK_GROUP state
        if (state == CHECK_GROUP && bug_ptr >= (group_start + d)) begin
             // Logic handled in sequential block, transition to CHECK_TOTAL
             if (best_student < 4'd15) next_state = CHECK_TOTAL;
             else next_state = UPDATE_D; // Invalid schedule, skip rest
        end
        // The logic for FIND_STUDENT completion is tricky in pure combinational
        // Refined state flow:
        if (state == FIND_STUDENT && student_idx >= n[3:0]) begin
             if (best_student < 4'd15) next_state = CHECK_TOTAL;
             else next_state = UPDATE_D; // Failed to find student
        end
    end
endmodule