module bug_fix_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] bug_complexity [0:7],
    input [7:0] student_ability [0:7],
    input [15:0] student_cost [0:7],
    input [15:0] budget,
    output reg [3:0] min_days,
    output reg [2:0] assignment [0:7],
    output reg done,
    output reg feasible
);

    // Internal Registers
    reg [7:0] sorted_bugs [0:7];
    reg [2:0] bug_map [0:7];
    
    // Binary Search Registers
    reg [3:0] search_low;
    reg [3:0] search_high;
    reg [3:0] current_days;
    
    // Check Schedule Registers
    reg [2:0] group_idx;
    reg [15:0] current_cost;
    reg check_pass;
    reg [2:0] temp_assignment [0:7];
    
    // Best Solution Registers
    reg [2:0] best_assignment [0:7];
    reg [3:0] best_days;
    reg best_feasible;

    // Counters for Sort (reusing registers to save space)
    reg [2:0] sort_pass;
    reg [2:0] sort_inner;

    // State Machine
    reg [2:0] state;
    localparam IDLE = 0;
    localparam SORT_BUGS = 1;
    localparam BINARY_SEARCH = 2;
    localparam CHECK_SCHEDULE = 3;
    localparam UPDATE_BS = 4;
    localparam DONE_STATE = 5;

    // Combinational Logic for Group Check
    wire [2:0] group_start_idx;
    wire [2:0] group_end_idx;
    wire [7:0] group_max;
    wire [15:0] group_cost_val;
    wire group_found;
    wire [2:0] group_student;

    // Helper: Max in range combinational
    reg [7:0] max_c;
    integer i;
    always @(*) begin
        max_c = 0;
        if (group_start_idx < 8) begin
            for (i = group_start_idx; i < group_end_idx && i < 8; i = i + 1) begin
                if (sorted_bugs[i] > max_c) max_c = sorted_bugs[i];
            end
        end
    end
    assign group_max = max_c;

    // Helper: Find cheapest student combinational
    reg [15:0] min_c;
    reg [2:0] best_s;
    reg found;
    integer j;
    always @(*) begin
        min_c = 16'hFFFF;
        best_s = 0;
        found = 0;
        if (group_start_idx < 8) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (student_ability[j] >= group_max) begin
                    if (student_cost[j] < min_c) begin
                        min_c = student_cost[j];
                        best_s = j;
                        found = 1;
                    end
                end
            end
        end
    end
    assign group_cost_val = min_c;
    assign group_found = found;
    assign group_student = best_s;

    // Group indices calculation
    // If current_days is 0, handle gracefully, but search range is 1-16.
    assign group_start_idx = group_idx * current_days;
    assign group_end_idx = (group_start_idx + current_days > 8) ? 8 : group_start_idx + current_days;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            feasible <= 0;
            min_days <= 0;
            search_low <= 1;
            search_high <= 16;
            sort_pass <= 0;
            sort_inner <= 0;
            // Reset arrays
            for (int k = 0; k < 8; k = k + 1) begin
                assignment[k] <= 0;
                best_assignment[k] <= 0;
                temp_assignment[k] <= 0;
                bug_map[k] <= k;
                sorted_bugs[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load bugs into sort buffer
                        for (int k = 0; k < 8; k = k + 1) begin
                            sorted_bugs[k] <= bug_complexity[k];
                            bug_map[k] <= k;
                        end
                        state <= SORT_BUGS;
                        sort_pass <= 0;
                        sort_inner <= 0;
                        best_feasible <= 0;
                    end
                end

                SORT_BUGS: begin
                    // Bubble Sort: 8 passes (sort_pass), each pass 7 comparisons (sort_inner)
                    if (sort_pass < 8) begin
                        if (sort_inner < 7) begin
                            // Compare adjacent elements
                            if (sorted_bugs[sort_inner] < sorted_bugs[sort_inner + 1]) begin
                                // Swap bugs
                                sorted_bugs[sort_inner] <= sorted_bugs[sort_inner + 1];
                                sorted_bugs[sort_inner + 1] <= sorted_bugs[sort_inner];
                                // Swap indices
                                bug_map[sort_inner] <= bug_map[sort_inner + 1];
                                bug_map[sort_inner + 1] <= bug_map[sort_inner];
                            end
                            sort_inner <= sort_inner + 1;
                        end else begin
                            // End of inner loop, next pass
                            sort_inner <= 0;
                            sort_pass <= sort_pass + 1;
                        end
                    end else begin
                        // Sorting Done
                        state <= BINARY_SEARCH;
                        search_low <= 1;
                        search_high <= 16;
                        best_feasible <= 0;
                    end
                end

                BINARY_SEARCH: begin
                    if (search_low <= search_high) begin
                        current_days <= (search_low + search_high) >> 1;
                        group_idx <= 0;
                        current_cost <= 0;
                        check_pass <= 1;
                        state <= CHECK_SCHEDULE;
                    end else begin
                        // Search Complete
                        if (best_feasible) begin
                            feasible <= 1;
                            min_days <= best_days;
                            // Map assignments: best_assignment[k] is for sorted bug k.
                            // We need assignment[original_id] = student.
                            // bug_map[k] gives original_id of sorted bug k.
                            // So assignment[bug_map[k]] = best_assignment[k].
                            // However, we can't loop combinationaly here easily for output.
                            // We will update assignment outputs in next cycle or keep them static.
                            // Let's map them now.
                            for (int k = 0; k < 8; k = k + 1) begin
                                assignment[bug_map[k]] <= best_assignment[k];
                            end
                            // Wait, if we do this in combinational logic, we need valid data.
                            // But bug_map and best_assignment are stable.
                        end else begin
                            feasible <= 0;
                            min_days <= 0;
                        end
                        state <= DONE_STATE;
                    end
                end

                CHECK_SCHEDULE: begin
                    // Process one group per cycle
                    if (group_start_idx < 8) begin
                        if (check_pass) begin
                            if (group_found) begin
                                if (current_cost + group_cost_val <= budget) begin
                                    current_cost <= current_cost + group_cost_val;
                                    temp_assignment[group_idx] <= group_student;
                                    group_idx <= group_idx + 1;
                                end else begin
                                    // Budget exceeded
                                    check_pass <= 0;
                                    group_idx <= group_idx + 1;
                                end
                            end else begin
                                // No student found for this group
                                check_pass <= 0;
                                group_idx <= group_idx + 1;
                            end
                        end else begin
                            // Already failed, just increment group_idx to consume cycles
                            group_idx <= group_idx + 1;
                        end
                    end else begin
                        // No more groups
                        state <= UPDATE_BS;
                    end
                end

                UPDATE_BS: begin
                    if (check_pass) begin
                        // This schedule works
                        best_days <= current_days;
                        best_feasible <= 1;
                        for (int k = 0; k < 8; k = k + 1) begin
                            best_assignment[k] <= temp_assignment[k];
                        end
                        // Try smaller days
                        search_high <= current_days - 1;
                    end else begin
                        // Try larger days
                        search_low <= current_days + 1;
                    end
                    state <= BINARY_SEARCH;
                end

                DONE_STATE: begin
                    done <= 1;
                    // Wait for start to go low to return to IDLE
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule
