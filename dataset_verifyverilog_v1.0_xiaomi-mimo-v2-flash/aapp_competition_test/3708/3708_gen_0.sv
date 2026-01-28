module volcano_path (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] m_count,
    input wire [15:0] volcano_x [0:63],
    input wire [15:0] volcano_y [0:63],
    output reg [31:0] result,
    output reg done
);

    // State machine definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] SORT_CHECK  = 3'd2;
    localparam [2:0] ROW_PROCESS = 3'd3;
    localparam [2:0] UPDATE_INTERVALS = 3'd4;
    localparam [2:0] CHECK_RESULT = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Input storage
    reg [15:0] n_reg;  // Grid size (16 max)
    reg [15:0] m_reg;  // Volcano count
    reg [15:0] vol_x [0:63];  // Volcano x coordinates
    reg [15:0] vol_y [0:63];  // Volcano y coordinates
    reg [15:0] sorted_x [0:63];  // Sorted by y (row)
    reg [15:0] sorted_y [0:63];  // Sorted by y (row)

    // Row processing
    reg [15:0] current_row;
    reg [15:0] row_idx;  // Index in sorted array for current row
    reg [15:0] volcano_idx;  // Index for volcano processing in current row

    // Interval management (max 8 intervals)
    reg [15:0] intervals_start [0:7];  // Start column of interval
    reg [15:0] intervals_end [0:7];    // End column of interval
    reg [15:0] intervals_count;        // Number of active intervals
    reg [15:0] new_intervals_start [0:7];
    reg [15:0] new_intervals_end [0:7];
    reg [15:0] new_intervals_count;

    // Volcano coordinates for current row
    reg [15:0] row_volcanoes [0:15];  // Max 16 volcanoes per row (since n=16)
    reg [15:0] row_volcano_count;
    reg [15:0] volcano_pos_idx;  // Position index in row_volcanoes array

    // Cycle counter for timeout prevention
    reg [15:0] cycle_counter;
    localparam [15:0] MAX_CYCLES = 16'd256;

    // Temporary variables
    reg [15:0] i, j, k;
    reg [15:0] temp_x, temp_y;
    reg [15:0] start_col, end_col;
    reg [15:0] volcano_col;
    reg [15:0] next_start, next_end;
    reg found_blocking;
    reg interval_split;
    reg [15:0] split_idx;

    // Sort signal
    reg sort_done;
    reg [15:0] sort_i, sort_j;
    reg [15:0] min_idx;

    // Helper function to sort volcanoes by y (row), then by x
    task sort_volcanoes;
        integer i, j, min_idx;
        reg [15:0] temp_x_val, temp_y_val;
    begin
        // Initialize sorted arrays
        for (i = 0; i < 64; i = i + 1) begin
            sorted_x[i] <= 16'd65535;
            sorted_y[i] <= 16'd65535;
        end
        // Copy to sorted arrays
        for (i = 0; i < 64; i = i + 1) begin
            sorted_x[i] <= vol_x[i];
            sorted_y[i] <= vol_y[i];
        end
        // Bubble sort (simple, small N)
        for (i = 0; i < 63; i = i + 1) begin
            for (j = 0; j < 63 - i; j = j + 1) begin
                // Compare by y first, then x
                if (sorted_y[j] > sorted_y[j+1] || 
                    (sorted_y[j] == sorted_y[j+1] && sorted_x[j] > sorted_x[j+1])) begin
                    // Swap
                    temp_x_val <= sorted_x[j];
                    temp_y_val <= sorted_y[j];
                    sorted_x[j] <= sorted_x[j+1];
                    sorted_y[j] <= sorted_y[j+1];
                    sorted_x[j+1] <= temp_x_val;
                    sorted_y[j+1] <= temp_y_val;
                end
            end
        end
    end
    endtask

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? INIT : IDLE;
            INIT: next_state = SORT_CHECK;
            SORT_CHECK: next_state = ROW_PROCESS;
            ROW_PROCESS: begin
                if (current_row > n_reg) begin
                    next_state = CHECK_RESULT;
                end else begin
                    next_state = UPDATE_INTERVALS;
                end
            end
            UPDATE_INTERVALS: next_state = ROW_PROCESS;
            CHECK_RESULT: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State machine execution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 16'd0;
            current_row <= 16'd0;
            row_idx <= 16'd0;
            volcano_idx <= 16'd0;
            intervals_count <= 16'd0;
            new_intervals_count <= 16'd0;
            row_volcano_count <= 16'd0;
            volcano_pos_idx <= 16'd0;
            for (i = 0; i < 8; i = i + 1) begin
                intervals_start[i] <= 16'd0;
                intervals_end[i] <= 16'd0;
                new_intervals_start[i] <= 16'd0;
                new_intervals_end[i] <= 16'd0;
            end
        end else begin
            cycle_counter <= cycle_counter + 16'd1;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset counters for new operation
                        cycle_counter <= 16'd0;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    // Load inputs
                    n_reg <= 16'd16;  // Fixed grid size per requirements
                    m_reg <= (m_count > 16'd64) ? 16'd64 : m_count;
                    // Copy volcano data (limited to 64)
                    for (i = 0; i < 64; i = i + 1) begin
                        vol_x[i] <= (i < m_count && i < 64) ? volcano_x[i] : 16'd65535;
                        vol_y[i] <= (i < m_count && i < 64) ? volcano_y[i] : 16'd65535;
                    end
                    // Initialize intervals (whole row is reachable at start)
                    intervals_count <= 16'd1;
                    intervals_start[0] <= 16'd1;  // Column 1
                    intervals_end[0] <= 16'd1;    // Just column 1 at start
                    current_row <= 16'd1;
                    row_idx <= 16'd0;
                end

                SORT_CHECK: begin
                    // Perform sorting of volcanoes
                    sort_volcanoes();
                end

                ROW_PROCESS: begin
                    if (current_row <= n_reg) begin
                        // Collect volcanoes in current row
                        row_volcano_count <= 16'd0;
                        volcano_pos_idx <= 16'd0;
                        
                        for (i = 0; i < 64; i = i + 1) begin
                            if (sorted_y[i] == current_row && sorted_x[i] >= 16'd1 && 
                                sorted_x[i] <= n_reg && row_volcano_count < 16'd16) begin
                                row_volcanoes[row_volcano_count] <= sorted_x[i];
                                row_volcano_count <= row_volcano_count + 16'd1;
                            end
                        end
                    end
                end

                UPDATE_INTERVALS: begin
                    if (current_row <= n_reg) begin
                        // Start with intervals from previous row
                        // For row 1, intervals are already set (col 1)
                        if (current_row > 16'd1) begin
                            // Propagate intervals to next row
                            intervals_count <= intervals_count;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < intervals_count) begin
                                    intervals_start[i] <= intervals_start[i];
                                    intervals_end[i] <= intervals_end[i];
                                end
                            end
                        end

                        // Process volcanoes in this row (if any)
                        new_intervals_count <= 16'd0;
                        
                        if (row_volcano_count == 16'd0) begin
                            // No volcanoes, just keep intervals
                            new_intervals_count <= intervals_count;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < intervals_count) begin
                                    new_intervals_start[i] <= intervals_start[i];
                                    new_intervals_end[i] <= intervals_end[i];
                                end
                            end
                        end else begin
                            // Process each interval against volcanoes in this row
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < intervals_count && intervals_start[i] <= intervals_end[i]) begin
                                    start_col <= intervals_start[i];
                                    end_col <= intervals_end[i];
                                    
                                    // Check if interval is blocked by any volcano in this row
                                    found_blocking <= 1'b0;
                                    
                                    for (j = 0; j < 16; j = j + 1) begin
                                        if (j < row_volcano_count) begin
                                            volcano_col <= row_volcanoes[j];
                                            
                                            // Check if volcano is within this interval
                                            if (row_volcanoes[j] >= intervals_start[i] && 
                                                row_volcanoes[j] <= intervals_end[i]) begin
                                                
                                                // Split interval
                                                if (row_volcanoes[j] == intervals_start[i]) begin
                                                    // Volcano at start of interval
                                                    if (row_volcanoes[j] < intervals_end[i]) begin
                                                        // Keep part after volcano
                                                        if (new_intervals_count < 8) begin
                                                            new_intervals_start[new_intervals_count] <= row_volcanoes[j] + 16'd1;
                                                            new_intervals_end[new_intervals_count] <= intervals_end[i];
                                                            new_intervals_count <= new_intervals_count + 16'd1;
                                                        end
                                                    end
                                                    // else entire interval is blocked
                                                end else if (row_volcanoes[j] == intervals_end[i]) begin
                                                    // Volcano at end of interval
                                                    if (row_volcanoes[j] > intervals_start[i]) begin
                                                        // Keep part before volcano
                                                        if (new_intervals_count < 8) begin
                                                            new_intervals_start[new_intervals_count] <= intervals_start[i];
                                                            new_intervals_end[new_intervals_count] <= row_volcanoes[j] - 16'd1;
                                                            new_intervals_count <= new_intervals_count + 16'd1;
                                                        end
                                                    end
                                                end else begin
                                                    // Volcano in middle - split into two
                                                    if (new_intervals_count < 7) begin
                                                        // Left part
                                                        new_intervals_start[new_intervals_count] <= intervals_start[i];
                                                        new_intervals_end[new_intervals_count] <= row_volcanoes[j] - 16'd1;
                                                        new_intervals_count <= new_intervals_count + 16'd1;
                                                        // Right part
                                                        new_intervals_start[new_intervals_count] <= row_volcanoes[j] + 16'd1;
                                                        new_intervals_end[new_intervals_count] <= intervals_end[i];
                                                        new_intervals_count <= new_intervals_count + 16'd1;
                                                    end
                                                end
                                            end else begin
                                                // Volcano outside this interval, no effect
                                            end
                                        end
                                    end
                                    
                                    // If no volcano in interval, keep it whole
                                    if (!found_blocking && new_intervals_count < 8) begin
                                        new_intervals_start[new_intervals_count] <= intervals_start[i];
                                        new_intervals_end[new_intervals_count] <= intervals_end[i];
                                        new_intervals_count <= new_intervals_count + 16'd1;
                                    end
                                end
                            end
                            
                            // Update intervals for next iteration
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < new_intervals_count) begin
                                    intervals_start[i] <= new_intervals_start[i];
                                    intervals_end[i] <= new_intervals_end[i];
                                end
                            end
                            intervals_count <= new_intervals_count;
                        end

                        // Check if all intervals are blocked
                        if (intervals_count == 16'd0 && current_row >= 16'd1) begin
                            // Path blocked
                            result <= 32'hFFFFFFFF;  // -1
                        end

                        // Move to next row
                        current_row <= current_row + 16'd1;
                    end
                end

                CHECK_RESULT: begin
                    if (result != 32'hFFFFFFFF) begin
                        // Check if we can reach (n,n)
                        // After processing all rows, check if column n is reachable
                        if (intervals_count > 16'd0) begin
                            // Check if column n is in any interval
                            found_blocking <= 1'b0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (i < intervals_count && !found_blocking) begin
                                    if (intervals_start[i] <= n_reg && intervals_end[i] >= n_reg) begin
                                        found_blocking <= 1'b1;
                                        result <= 32'd2 * (n_reg - 16'd1);
                                    end
                                end
                            end
                            if (!found_blocking) begin
                                result <= 32'hFFFFFFFF;
                            end
                        end else begin
                            result <= 32'hFFFFFFFF;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    // Clear for next start
                    state <= IDLE;
                    // Keep result until next start
                end

                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule