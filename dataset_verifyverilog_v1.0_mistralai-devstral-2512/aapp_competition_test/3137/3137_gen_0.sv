module bacteria_simulation(
    input clk,
    input rst_n,
    input start,
    input [3:0] trap_row,
    input [3:0] trap_col,
    input [3:0] start_row_0, input [3:0] start_col_0, input [1:0] start_dir_0, input [3:0] grid_0 [0:63],
    input [3:0] start_row_1, input [3:0] start_col_1, input [1:0] start_dir_1, input [3:0] grid_1 [0:63],
    input [3:0] start_row_2, input [3:0] start_col_2, input [1:0] start_dir_2, input [3:0] grid_2 [0:63],
    input [3:0] start_row_3, input [3:0] start_col_3, input [1:0] start_dir_3, input [3:0] grid_3 [0:63],
    input [3:0] start_row_4, input [3:0] start_col_4, input [1:0] start_dir_4, input [3:0] grid_4 [0:63],
    output reg [15:0] result,
    output reg done
);

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd256;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] STEP = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    localparam [2:0] LOOP_STATE = 3'd5;

    // State and control
    reg [2:0] state, next_state;
    reg [7:0] time;
    reg [7:0] cycle_count;

    // Bacteria state (5 bacteria)
    reg [3:0] row [0:4];
    reg [3:0] col [0:4];
    reg [1:0] dir [0:4];

    // State history for cycle detection (simplified: track last 8 states via hash)
    reg [31:0] state_hash_history [0:7];
    reg [31:0] current_state_hash;
    integer i, j;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            time <= 8'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            // Initialize bacteria positions and directions
            for (i = 0; i < 5; i = i + 1) begin
                case (i)
                    0: begin row[i] <= start_row_0; col[i] <= start_col_0; dir[i] <= start_dir_0; end
                    1: begin row[i] <= start_row_1; col[i] <= start_col_1; dir[i] <= start_dir_1; end
                    2: begin row[i] <= start_row_2; col[i] <= start_col_2; dir[i] <= start_dir_2; end
                    3: begin row[i] <= start_row_3; col[i] <= start_col_3; dir[i] <= start_dir_3; end
                    4: begin row[i] <= start_row_4; col[i] <= start_col_4; dir[i] <= start_dir_4; end
                endcase
            end
            // Clear state history
            for (j = 0; j < 8; j = j + 1) begin
                state_hash_history[j] <= 32'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    next_state <= STEP;
                end

                STEP: begin
                    // Process each bacterium
                    for (i = 0; i < 5; i = i + 1) begin
                        // Read grid value
                        reg [3:0] grid_val;
                        case (i)
                            0: grid_val = grid_0[{row[i], col[i]}];
                            1: grid_val = grid_1[{row[i], col[i]}];
                            2: grid_val = grid_2[{row[i], col[i]}];
                            3: grid_val = grid_3[{row[i], col[i]}];
                            4: grid_val = grid_4[{row[i], col[i]}];
                        endcase

                        // Update direction
                        reg [1:0] new_dir = (dir[i] + grid_val) % 4;

                        // Check boundaries and flip if needed
                        if ((new_dir == 2'd0 && row[i] == 4'd0) ||  // Up from row 0
                            (new_dir == 2'd1 && col[i] == 4'd7) ||  // Right from col 7
                            (new_dir == 2'd2 && row[i] == 4'd7) ||  // Down from row 7
                            (new_dir == 2'd3 && col[i] == 4'd0)) begin // Left from col 0
                            new_dir = (new_dir + 2'd2) % 4;
                        end

                        // Update position
                        case (new_dir)
                            2'd0: row[i] <= row[i] - 4'd1;  // Up
                            2'd1: col[i] <= col[i] + 4'd1;  // Right
                            2'd2: row[i] <= row[i] + 4'd1;  // Down
                            2'd3: col[i] <= col[i] - 4'd1;  // Left
                        endcase

                        dir[i] <= new_dir;
                    end
                    next_state <= CHECK;
                end

                CHECK: begin
                    // Check if all bacteria are at trap
                    reg all_at_trap = 1'b1;
                    for (i = 0; i < 5; i = i + 1) begin
                        if (row[i] != trap_row || col[i] != trap_col) begin
                            all_at_trap = 1'b0;
                        end
                    end

                    if (all_at_trap) begin
                        result <= time;
                        next_state <= DONE_STATE;
                    end else begin
                        // Check for cycle (simplified: compute hash and compare)
                        reg [31:0] new_hash = 32'd0;
                        for (i = 0; i < 5; i = i + 1) begin
                            new_hash = new_hash ^ {row[i], col[i], dir[i]};
                        end
                        current_state_hash = new_hash;

                        reg found = 1'b0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (state_hash_history[j] == current_state_hash) begin
                                found = 1'b1;
                            end
                        end

                        if (found || time >= MAX_CYCLES) begin
                            result <= 16'd65535;  // -1 in 16-bit unsigned
                            next_state <= LOOP_STATE;
                        end else begin
                            // Update history (shift and add new hash)
                            for (j = 0; j < 7; j = j + 1) begin
                                state_hash_history[j] <= state_hash_history[j + 1];
                            end
                            state_hash_history[7] <= current_state_hash;

                            time <= time + 8'd1;
                            next_state <= STEP;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                LOOP_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule