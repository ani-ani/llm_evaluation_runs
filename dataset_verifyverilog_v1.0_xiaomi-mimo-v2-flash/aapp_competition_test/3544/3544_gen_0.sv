module CinemaSeating(
    input clk,
    input rst_n,
    input start,
    input [3:0] group_count [1:12],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALCULATE  = 3'd1;
    localparam [2:0] CHECK_X    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] X;                     // Current row width being tested
    reg [3:0] row_idx;               // Current row index
    reg [3:0] remaining_seats;       // Remaining seats in current row
    reg [5:0] group_counter[1:12];   // Copy of group counts for simulation
    reg [5:0] group_type;            // Current group size being placed
    reg [3:0] i, j;                  // Loop variables
    reg valid_x;                     // Flag if current X is valid
    reg all_done;                    // Flag if all groups placed for current X
    reg [3:0] last_row_idx;          // For generating row lengths
    reg [3:0] current_row_len;       // Length of current row
    reg [3:0] groups_processed;      // Track how many group types processed

    // FSM Sequencing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            X <= 4'd3;
            row_idx <= 4'd0;
            remaining_seats <= 4'd0;
            group_type <= 6'd1;
            valid_x <= 1'b0;
            all_done <= 1'b0;
            groups_processed <= 4'd0;
            current_row_len <= 4'd0;
            // Initialize group counters
            for (i = 4'd1; i <= 12; i = i + 1) begin
                group_counter[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    X <= 4'd3;
                    result <= 8'd0;
                    // Initialize counters from inputs
                    for (i = 4'd1; i <= 12; i = i + 1) begin
                        group_counter[i] <= {2'd0, group_count[i]};
                    end
                end

                CALCULATE: begin
                    // Reset simulation for current X
                    row_idx <= 4'd0;
                    groups_processed <= 4'd0;
                    valid_x <= 1'b1;
                    // Re-initialize group counter copy
                    for (i = 4'd1; i <= 12; i = i + 1) begin
                        group_counter[i] <= {2'd0, group_count[i]};
                    end
                end

                CHECK_X: begin
                    // Process rows for current X
                    if (row_idx < X) begin
                        // Calculate row length: X, X-1, ..., 1
                        current_row_len <= X - row_idx;
                        remaining_seats <= X - row_idx;
                        row_idx <= row_idx + 4'd1;
                        group_type <= 6'd12; // Start with largest groups
                    end else if (groups_processed < 12) begin
                        // Check remaining groups (sizes 1 to current-1)
                        if (group_counter[groups_processed + 4'd1] > 0) begin
                            valid_x <= 1'b0;
                        end
                        groups_processed <= groups_processed + 4'd1;
                    end else begin
                        // All groups processed
                        if (valid_x) begin
                            result <= {4'd0, X};
                            done <= 1'b1;
                            next_state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational logic for group placement within a row
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALCULATE;
            end

            CALCULATE: begin
                next_state = CHECK_X;
            end

            CHECK_X: begin
                if (row_idx < X) begin
                    // Still processing rows for current X
                    next_state = CHECK_X;
                end else if (groups_processed < 12) begin
                    // Checking if all groups of size 'groups_processed + 1' were placed
                    if (group_counter[groups_processed + 4'd1] > 0) begin
                        // Failed for this X
                        if (X < 4'd12) begin
                            X = X + 4'd1;
                            next_state = CALCULATE;
                        end else begin
                            result = 8'hFF;
                            done = 1'b1;
                            next_state = DONE_STATE;
                        end
                    end else begin
                        // Continue checking next group size
                        next_state = CHECK_X;
                    end
                end else begin
                    // All groups processed successfully for current X
                    if (!valid_x) begin
                        // Should have caught earlier, but safety check
                        if (X < 4'd12) begin
                            X = X + 4'd1;
                            next_state = CALCULATE;
                        end else begin
                            result = 8'hFF;
                            done = 1'b1;
                            next_state = DONE_STATE;
                        end
                    end else begin
                        // Valid X found
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Process groups within current row
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM
        end else if (state == CHECK_X && row_idx <= X) begin
            // Place groups in current row (process largest remaining first)
            if (group_type > 4'd0) begin
                if (group_counter[group_type] > 0) begin
                    // Try to place this group
                    if (group_type <= remaining_seats) begin
                        // Place group
                        group_counter[group_type] <= group_counter[group_type] - 6'd1;
                        // Consume seats: group size + separator (unless at row end)
                        if ((remaining_seats - group_type) == 0) begin
                            remaining_seats <= 4'd0; // At row end, no separator needed
                        end else begin
                            remaining_seats <= remaining_seats - group_type - 4'd1;
                        end
                    end else begin
                        // Cannot place, try smaller group
                        group_type <= group_type - 4'd1;
                    end
                end else begin
                    // No more groups of this size, try smaller
                    group_type <= group_type - 4'd1;
                end
            end else if (group_type == 4'd1) begin
                // Already tried size 1, move to next row
                group_type <= 4'd12;
            end
        end
    end

endmodule