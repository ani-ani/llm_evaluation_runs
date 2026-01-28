module HunterExam(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid_char,
    input wire [31:0] score_val,
    input wire found_result,
    output reg req_read,
    output reg req_score,
    output reg [15:0] read_addr,
    output reg [5:0] read_col,
    output reg [31:0] total_score,
    output reg done
);

    // Parameters
    localparam [15:0] R_MAX = 16'd50;
    localparam [15:0] C_MAX = 16'd50;
    localparam [31:0] K_MAX = 32'd1000000000;
    localparam [15:0] MAX_STEPS = 16'd4096;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FETCH_GRID = 4'd1;
    localparam [3:0] EXEC_STEP = 4'd2;
    localparam [3:0] CHECK_CYCLE = 4'd3;
    localparam [3:0] CALC_SCORE = 4'd4;
    localparam [3:0] WAIT_K = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    // Registers
    reg [3:0] state, next_state;
    reg [31:0] K;
    reg [15:0] R, C;
    reg [5:0] row, col;
    reg [31:0] current_score, cycle_score;
    reg [15:0] step_count, cycle_len;
    reg [15:0] cycle_start_step;
    reg [5:0] cycle_start_row, cycle_start_col;
    reg [31:0] parts_processed;
    reg [31:0] remaining_parts;
    reg [15:0] i;

    // History buffer for cycle detection
    reg [11:0] history [0:63]; // 64 entries, each 12 bits (6-bit row, 6-bit col)
    reg [5:0] history_ptr;

    // FSM State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            req_read <= 1'b0;
            req_score <= 1'b0;
            read_addr <= 16'd0;
            read_col <= 6'd0;
            total_score <= 32'd0;
            done <= 1'b0;
            K <= 32'd0;
            R <= 16'd0;
            C <= 16'd0;
            row <= 6'd0;
            col <= 6'd0;
            current_score <= 32'd0;
            cycle_score <= 32'd0;
            step_count <= 16'd0;
            cycle_len <= 16'd0;
            cycle_start_step <= 16'd0;
            cycle_start_row <= 6'd0;
            cycle_start_col <= 6'd0;
            parts_processed <= 32'd0;
            remaining_parts <= 32'd0;
            i <= 16'd0;
            history_ptr <= 6'd0;
            for (i = 0; i < 64; i = i + 1) begin
                history[i] <= 12'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        req_read = 1'b0;
        req_score = 1'b0;
        read_addr = 16'd0;
        read_col = 6'd0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = FETCH_GRID;
                    // Initialize for new run
                    K = 32'd1000000000; // Default K (can be parameterized)
                    R = 16'd50; // Default R
                    C = 16'd50; // Default C
                    row = 6'd1; // Start at row 1
                    col = 6'd0; // Start at col 0
                    current_score = 32'd0;
                    step_count = 16'd0;
                    parts_processed = 32'd0;
                    remaining_parts = 32'd0;
                    cycle_len = 16'd0;
                    cycle_score = 32'd0;
                    history_ptr = 6'd0;
                    for (i = 0; i < 64; i = i + 1) begin
                        history[i] = 12'd0;
                    end
                end
            end

            FETCH_GRID: begin
                req_read = 1'b1;
                read_addr = {row, col};
                if (found_result) begin
                    next_state = EXEC_STEP;
                end
            end

            EXEC_STEP: begin
                // Execute one step based on grid_char
                if (grid_char == "R") begin
                    col = col + 6'd1;
                end else if (grid_char == "L") begin
                    col = col - 6'd1;
                end else if (grid_char == "." || grid_char == "?") begin
                    row = row + 6'd1;
                end

                // Check bounds and obstacles
                if (row > R || col < 6'd0 || col >= C || grid_char == "X") begin
                    next_state = DONE_STATE;
                    total_score = current_score;
                    done = 1'b1;
                end else if (row == R) begin
                    // Reached bottom row, add score
                    req_score = 1'b1;
                    read_col = col;
                    if (found_result) begin
                        current_score = current_score + score_val;
                        parts_processed = parts_processed + 32'd1;
                        if (parts_processed >= K) begin
                            next_state = DONE_STATE;
                            total_score = current_score;
                            done = 1'b1;
                        end else begin
                            row = 6'd1; // Reset to top
                            col = col; // Keep same column
                            next_state = CHECK_CYCLE;
                        end
                    end
                end else begin
                    next_state = CHECK_CYCLE;
                end

                // Update step count
                step_count = step_count + 16'd1;
            end

            CHECK_CYCLE: begin
                // Check for cycle
                for (i = 0; i < history_ptr; i = i + 1) begin
                    if (history[i] == {row, col}) begin
                        // Cycle detected
                        cycle_start_step = i;
                        cycle_start_row = history[i][5:0];
                        cycle_start_col = history[i][11:6];
                        cycle_len = step_count - cycle_start_step;
                        cycle_score = current_score - (cycle_start_row == 6'd1 && cycle_start_col == col ? 32'd0 : 32'd0); // Simplified
                        remaining_parts = K - parts_processed;
                        next_state = CALC_SCORE;
                    end
                end

                // Store current state in history
                if (history_ptr < 64) begin
                    history[history_ptr] = {row, col};
                    history_ptr = history_ptr + 6'd1;
                end

                // Continue to next step
                next_state = FETCH_GRID;
            end

            CALC_SCORE: begin
                // Calculate total score with cycle
                if (cycle_len > 16'd0) begin
                    total_score = current_score + (remaining_parts / cycle_len) * cycle_score;
                    // Add remaining steps score (simplified)
                    total_score = total_score + (remaining_parts % cycle_len) * (cycle_score / cycle_len);
                end else begin
                    total_score = current_score;
                end
                next_state = DONE_STATE;
                done = 1'b1;
            end

            DONE_STATE: begin
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule