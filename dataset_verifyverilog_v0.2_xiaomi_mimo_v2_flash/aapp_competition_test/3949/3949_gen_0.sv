module monopole_magnet_solver(
    input clk,
    input rst_n,
    input start,
    input [5:0] grid_flat [0:15],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_ROWS = 3'b001;
    localparam CHECK_COLS = 3'b010;
    localparam CHECK_EMPTY = 3'b011;
    localparam COUNT_COMPONENTS = 3'b100;
    localparam DONE = 3'b101;
    localparam ERROR = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // Grid memory (reconstruct 2D array for readability)
    wire grid [0:3][0:3];
    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin : gen_grid_map
            for (c = 0; c < 4; c = c + 1) begin : gen_col_map
                assign grid[r][c] = grid_flat[r*4 + c][0];
            end
        end
    endgenerate

    // Internal Registers
    reg [1:0] row_idx;
    reg [1:0] col_idx;
    reg [1:0] scan_idx;

    // Constraint flags
    reg has_empty_row;
    reg has_empty_col;
    reg invalid_row;
    reg invalid_col;

    // DFS Registers
    reg [15:0] visited;
    reg [3:0] component_count;

    // Stack for DFS (Simple shift register implementation for up to 16 cells)
    // We only need to store indices (0-15)
    reg [3:0] stack [0:15];
    reg [3:0] sp; // Stack Pointer (points to next free location)
    reg [3:0] curr_idx;

    // Neighbor calculation helpers
    wire [3:0] up_idx = (curr_idx >= 4) ? curr_idx - 4 : 16;
    wire [3:0] down_idx = (curr_idx < 12) ? curr_idx + 4 : 16;
    wire [3:0] left_idx = (curr_idx[1:0] != 0) ? curr_idx - 1 : 16;
    wire [3:0] right_idx = (curr_idx[1:0] != 3) ? curr_idx + 1 : 16;

    // Helper to map flat index to row/col
    wire [1:0] curr_row = curr_idx[3:2];
    wire [1:0] curr_col = curr_idx[1:0];

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic & Output Logic (Clocked)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 4'b0;
            row_idx <= 2'b0;
            col_idx <= 2'b0;
            scan_idx <= 2'b0;
            has_empty_row <= 1'b0;
            has_empty_col <= 1'b0;
            invalid_row <= 1'b0;
            invalid_col <= 1'b0;
            visited <= 16'b0;
            component_count <= 4'b0;
            sp <= 4'b0;
            curr_idx <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        row_idx <= 2'b0;
                        col_idx <= 2'b0;
                        scan_idx <= 2'b0;
                        has_empty_row <= 1'b0;
                        has_empty_col <= 1'b0;
                        invalid_row <= 1'b0;
                        invalid_col <= 1'b0;
                        visited <= 16'b0;
                        component_count <= 4'b0;
                        sp <= 4'b0;
                    end
                end

                CHECK_ROWS: begin
                    if (row_idx < 4) begin
                        if (scan_idx == 0) begin
                            current_check_failed <= 1'b0;
                        end else begin
                            if (grid[row_idx][inner_scan]) begin
                                if (current_check_failed) begin
                                    invalid_row <= 1'b1;
                                end
                            end else begin
                                if (!current_check_failed) begin
                                    if (inner_scan > 0 && grid[row_idx][inner_scan-1]) begin
                                        current_check_failed <= 1'b1;
                                    end
                                end
                            end
                        end
                        if (inner_scan < 3) begin
                            inner_scan <= inner_scan + 1;
                        end else begin
                            if (!(grid[row_idx][0] || grid[row_idx][1] || grid[row_idx][2] || grid[row_idx][3])) begin
                                has_empty_row <= 1'b1;
                            end
                            if (row_idx < 3) begin
                                row_idx <= row_idx + 1;
                                inner_scan <= 0;
                                current_check_failed <= 1'b0;
                            end else begin
                                if (invalid_row) begin
                                    state <= ERROR;
                                end else begin
                                    state <= CHECK_COLS;
                                    col_idx <= 2'b0;
                                    inner_scan <= 2'b0;
                                    current_check_failed <= 1'b0;
                                end
                            end
                        end
                    end
                end

                CHECK_COLS: begin
                    if (inner_scan == 0) begin
                        current_check_failed <= 1'b0;
                    end else begin
                        if (grid[inner_scan][col_idx]) begin
                            if (current_check_failed) begin
                                invalid_col <= 1'b1;
                            end
                        end else begin
                            if (!current_check_failed) begin
                                if (inner_scan > 0 && grid[inner_scan-1][col_idx]) begin
                                    current_check_failed <= 1'b1;
                                end
                            end
                        end
                    end
                    if (inner_scan < 3) begin
                        inner_scan <= inner_scan + 1;
                    end else begin
                        if (!(grid[0][col_idx] || grid[1][col_idx] || grid[2][col_idx] || grid[3][col_idx])) begin
                            has_empty_col <= 1'b1;
                        end
                        if (col_idx < 3) begin
                            col_idx <= col_idx + 1;
                            inner_scan <= 0;
                            current_check_failed <= 1'b0;
                        end else begin
                            if (invalid_col) begin
                                state <= ERROR;
                            end else begin
                                state <= CHECK_EMPTY;
                            end
                        end
                    end
                end

                CHECK_EMPTY: begin
                    if (has_empty_row != has_empty_col) begin
                        state <= ERROR;
                    end else begin
                        state <= COUNT_COMPONENTS;
                        visited <= 16'b0;
                        component_count <= 4'b0;
                        sp <= 4'b0;
                        scan_idx <= 4'b0;
                    end
                end

                COUNT_COMPONENTS: begin
                    if (sp > 0) begin
                        if (current_check_failed) begin
                            case (inner_scan)
                                0: begin
                                    if (curr_idx >= 4 && !visited[up_idx] && grid[up_idx[3:2]][up_idx[1:0]]) begin
                                        stack[sp] <= up_idx;
                                        sp <= sp + 1;
                                        visited[up_idx] <= 1'b1;
                                    end
                                end
                                1: begin
                                    if (curr_idx < 12 && !visited[down_idx] && grid[down_idx[3:2]][down_idx[1:0]]) begin
                                        stack[sp] <= down_idx;
                                        sp <= sp + 1;
                                        visited[down_idx] <= 1'b1;
                                    end
                                end
                                2: begin
                                    if (curr_idx[1:0] != 0 && !visited[left_idx] && grid[left_idx[3:2]][left_idx[1:0]]) begin
                                        stack[sp] <= left_idx;
                                        sp <= sp + 1;
                                        visited[left_idx] <= 1'b1;
                                    end
                                end
                                3: begin
                                    if (curr_idx[1:0] != 3 && !visited[right_idx] && grid[right_idx[3:2]][right_idx[1:0]]) begin
                                        stack[sp] <= right_idx;
                                        sp <= sp + 1;
                                        visited[right_idx] <= 1'b1;
                                    end
                                end
                            endcase
                            if (inner_scan < 3) begin
                                inner_scan <= inner_scan + 1;
                            end else begin
                                current_check_failed <= 1'b0;
                            end
                        end else begin
                            if (sp > 0) begin
                                curr_idx <= stack[sp - 1];
                                sp <= sp - 1;
                                current_check_failed <= 1'b1;
                                inner_scan <= 0;
                            end else begin
                                if (scan_idx < 16) begin
                                    if (!visited[scan_idx] && grid[scan_idx[3:2]][scan_idx[1:0]]) begin
                                        component_count <= component_count + 1;
                                        visited[scan_idx] <= 1'b1;
                                        stack[0] <= scan_idx;
                                        sp <= 4'd1;
                                        current_check_failed <= 1'b1;
                                    end else begin
                                        scan_idx <= scan_idx + 1;
                                    end
                                end else begin
                                    state <= DONE;
                                end
                            end
                        end
                    end else begin
                        if (!current_check_failed) begin
                            if (scan_idx < 16) begin
                                if (!visited[scan_idx] && grid[scan_idx[3:2]][scan_idx[1:0]]) begin
                                    component_count <= component_count + 1;
                                    visited[scan_idx] <= 1'b1;
                                    stack[0] <= scan_idx;
                                    sp <= 4'd1;
                                    current_check_failed <= 1'b1;
                                end else begin
                                    scan_idx <= scan_idx + 1;
                                end
                            end else begin
                                state <= DONE;
                            end
                        end else begin
                            if (inner_scan == 0) begin
                                curr_idx <= stack[sp - 1];
                                sp <= sp - 1;
                                inner_scan <= 1;
                            end else if (inner_scan <= 4) begin
                                case (inner_scan - 1)
                                    0: begin
                                        if (curr_idx >= 4 && !visited[up_idx] && grid[up_idx[3:2]][up_idx[1:0]]) begin
                                            stack[sp] <= up_idx;
                                            sp <= sp + 1;
                                            visited[up_idx] <= 1'b1;
                                        end
                                    end
                                    1: begin
                                        if (curr_idx < 12 && !visited[down_idx] && grid[down_idx[3:2]][down_idx[1:0]]) begin
                                            stack[sp] <= down_idx;
                                            sp <= sp + 1;
                                            visited[down_idx] <= 1'b1;
                                        end
                                    end
                                    2: begin
                                        if (curr_idx[1:0] != 0 && !visited[left_idx] && grid[left_idx[3:2]][left_idx[1:0]]) begin
                                            stack[sp] <= left_idx;
                                            sp <= sp + 1;
                                            visited[left_idx] <= 1'b1;
                                        end
                                    end
                                    3: begin
                                        if (curr_idx[1:0] != 3 && !visited[right_idx] && grid[right_idx[3:2]][right_idx[1:0]]) begin
                                            stack[sp] <= right_idx;
                                            sp <= sp + 1;
                                            visited[right_idx] <= 1'b1;
                                        end
                                    end
                                endcase
                                inner_scan <= inner_scan + 1;
                            end else begin
                                if (sp > 0) begin
                                    inner_scan <= 0;
                                end else begin
                                    current_check_failed <= 1'b0;
                                    scan_idx <= scan_idx + 1;
                                    inner_scan <= 0;
                                end
                            end
                        end
                    end
                end

                DONE: begin
                    result <= component_count;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                ERROR: begin
                    result <= 4'b1111;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // --- Combinational Logic for Transition & Helper calculations ---
    reg row_is_valid;
    reg col_is_valid;
    reg [1:0] temp_r, temp_c;

    // Helper: Check Row Validity
    always @(*) begin
        row_is_valid = 1'b1;
    end

    // --- Combinational Next State & Helper Logic ---
    always @(*) begin
        next_state = state;
    end

    // Helper: Is grid cell black at (r, c)
    // We already have 'grid' wire array.

    reg [1:0] inner_scan; // Used for row/col scanning inside the state
    reg logic_error;
    reg current_check_failed;

endmodule

module TopModule ();
    // Empty wrapper for compilation if needed, but the task asks for the module itself.
    // The code above is the module `monopole_magnet_solver`.
endmodule