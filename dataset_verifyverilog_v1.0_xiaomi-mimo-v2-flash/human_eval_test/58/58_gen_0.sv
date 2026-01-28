module compute_sorted_intersection (
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:15],
    input [7:0] list2 [0:15],
    input [4:0] len1,
    input [4:0] len2,
    output reg [7:0] result [0:15],
    output reg [4:0] result_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SORT1    = 3'd1;
    localparam [2:0] SORT2    = 3'd2;
    localparam [2:0] INTERSECT = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] sorted1 [0:15];
    reg [7:0] sorted2 [0:15];
    reg [4:0] i, j, k, m, n;
    reg [7:0] temp;
    reg [4:0] current_len1;
    reg [4:0] current_len2;
    reg [4:0] result_index;
    reg [7:0] last_result;
    reg [7:0] last_input;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20; // Safe upper bound

    // Control signals
    reg sort_enable;
    reg sort_done;
    reg intersect_enable;
    reg intersect_done;

    // For insertion sort state machine
    localparam [1:0] SORT_IDLE = 2'd0;
    localparam [1:0] SORT_FIND = 2'd1;
    localparam [1:0] SORT_SHIFT = 2'd2;
    localparam [1:0] SORT_INSERT = 2'd3;

    reg [1:0] sort_state;
    reg sort_list; // 0 for list1, 1 for list2
    reg [4:0] sort_idx;
    reg [4:0] sort_loop_idx;
    reg [7:0] sort_value;

    // Internal assignment for combinational logic
    integer idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 5'd0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result[idx] <= 8'd0;
                sorted1[idx] <= 8'd0;
                sorted2[idx] <= 8'd0;
            end
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            m <= 5'd0;
            n <= 5'd0;
            result_index <= 5'd0;
            cycle_count <= 5'd0;
            current_len1 <= 5'd0;
            current_len2 <= 5'd0;
            sort_enable <= 1'b0;
            intersect_enable <= 1'b0;
            sort_state <= SORT_IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 5'd0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= SORT1;
                        // Copy list1 to sorted1 (remove duplicates logic handled in sort)
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < len1)
                                sorted1[idx] <= list1[idx];
                            else
                                sorted1[idx] <= 8'd0;
                        end
                        current_len1 <= len1;
                        // Initialize sort variables
                        sort_list <= 1'b0;
                        sort_idx <= 5'd1; // Start from second element (index 1)
                        sort_enable <= 1'b1;
                        sort_state <= SORT_FIND;
                    end
                end

                SORT1: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (sort_enable && sort_state == SORT_IDLE && sort_idx == current_len1) begin
                        // Finished sorting list1
                        sort_enable <= 1'b0;
                        state <= SORT2;
                        // Prepare for list2
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < len2)
                                sorted2[idx] <= list2[idx];
                            else
                                sorted2[idx] <= 8'd0;
                        end
                        current_len2 <= len2;
                        sort_list <= 1'b1;
                        sort_idx <= 5'd1;
                        sort_enable <= 1'b1;
                        sort_state <= SORT_FIND;
                    end
                    // Insertion Sort Logic
                    else if (sort_enable) begin
                        case (sort_state)
                            SORT_FIND: begin
                                sort_value <= (sort_list == 1'b0) ? sorted1[sort_idx] : sorted2[sort_idx];
                                sort_loop_idx <= sort_idx;
                                sort_state <= SORT_SHIFT;
                            end
                            SORT_SHIFT: begin
                                if (sort_loop_idx > 5'd0) begin
                                    reg [7:0] prev_val;
                                    prev_val = (sort_list == 1'b0) ? sorted1[sort_loop_idx - 5'd1] : sorted2[sort_loop_idx - 5'd1];
                                    // If prev_val > sort_value, shift and continue
                                    // If prev_val == sort_value (duplicate), skip shift
                                    if (prev_val > sort_value) begin
                                        if (sort_list == 1'b0)
                                            sorted1[sort_loop_idx] <= prev_val;
                                        else
                                            sorted2[sort_loop_idx] <= prev_val;
                                        sort_loop_idx <= sort_loop_idx - 5'd1;
                                        // stay in SORT_SHIFT
                                    end else if (prev_val == sort_value) begin
                                        // Duplicate found, don't insert this one, reduce length
                                        if (sort_list == 1'b0)
                                            current_len1 <= current_len1 - 5'd1;
                                        else
                                            current_len2 <= current_len2 - 5'd1;
                                        sort_state <= SORT_IDLE;
                                        sort_idx <= sort_idx + 5'd1;
                                    end else begin
                                        // prev_val < sort_value, found insertion point
                                        sort_state <= SORT_INSERT;
                                    end
                                end else begin
                                    // Reached beginning of array
                                    sort_state <= SORT_INSERT;
                                end
                            end
                            SORT_INSERT: begin
                                if (sort_list == 1'b0)
                                    sorted1[sort_loop_idx] <= sort_value;
                                else
                                    sorted2[sort_loop_idx] <= sort_value;
                                sort_state <= SORT_IDLE;
                                sort_idx <= sort_idx + 5'd1;
                            end
                            default: sort_state <= SORT_IDLE;
                        endcase
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= SORT2; // Force progression
                    end
                end

                SORT2: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (sort_enable && sort_state == SORT_IDLE && sort_idx == current_len2) begin
                        // Finished sorting list2
                        sort_enable <= 1'b0;
                        state <= INTERSECT;
                        i <= 5'd0;
                        j <= 5'd0;
                        result_index <= 5'd0;
                        intersect_enable <= 1'b1;
                        last_result <= 8'd0; // Initialize
                    end
                    // Insertion Sort Logic (same as above)
                    else if (sort_enable) begin
                        case (sort_state)
                            SORT_FIND: begin
                                sort_value <= sorted2[sort_idx];
                                sort_loop_idx <= sort_idx;
                                sort_state <= SORT_SHIFT;
                            end
                            SORT_SHIFT: begin
                                if (sort_loop_idx > 5'd0) begin
                                    reg [7:0] prev_val;
                                    prev_val = sorted2[sort_loop_idx - 5'd1];
                                    if (prev_val > sort_value) begin
                                        sorted2[sort_loop_idx] <= prev_val;
                                        sort_loop_idx <= sort_loop_idx - 5'd1;
                                    end else if (prev_val == sort_value) begin
                                        current_len2 <= current_len2 - 5'd1;
                                        sort_state <= SORT_IDLE;
                                        sort_idx <= sort_idx + 5'd1;
                                    end else begin
                                        sort_state <= SORT_INSERT;
                                    end
                                end else begin
                                    sort_state <= SORT_INSERT;
                                end
                            end
                            SORT_INSERT: begin
                                sorted2[sort_loop_idx] <= sort_value;
                                sort_state <= SORT_IDLE;
                                sort_idx <= sort_idx + 5'd1;
                            end
                            default: sort_state <= SORT_IDLE;
                        endcase
                    end
                    if (cycle_count >= MAX_CYCLES + 5'd10) begin
                        state <= INTERSECT;
                        i <= 5'd0;
                        j <= 5'd0;
                        result_index <= 5'd0;
                        intersect_enable <= 1'b1;
                    end
                end

                INTERSECT: begin
                    if (intersect_enable) begin
                        if (i < current_len1 && j < current_len2) begin
                            if (sorted1[i] < sorted2[j]) begin
                                i <= i + 5'd1;
                            end else if (sorted1[i] > sorted2[j]) begin
                                j <= j + 5'd1;
                            end else begin
                                // Match found
                                // Check if duplicate in result (compare with last added)
                                if (result_index == 5'd0 || sorted1[i] != last_result) begin
                                    result[result_index] <= sorted1[i];
                                    last_result <= sorted1[i];
                                    result_index <= result_index + 5'd1;
                                end
                                i <= i + 5'd1;
                                j <= j + 5'd1;
                            end
                        end else begin
                            intersect_enable <= 1'b0;
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    result_len <= result_index;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule