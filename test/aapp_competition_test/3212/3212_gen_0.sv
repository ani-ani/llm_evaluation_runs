module snake_path_finder(
    input clk,
    input rst_n,
    input start,
    input [23:0] snake_data,
    input snake_valid,
    input [7:0] snake_count,
    output reg [15:0] entry_exit,
    output reg valid_out,
    output reg bitten
);

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------
    localparam MAX_SNAKES   = 16;
    localparam FIELD_MAX_X  = 8'd255;
    localparam FIELD_MIN_X  = 8'd0;
    localparam FIELD_MIN_Y  = 8'd0;
    localparam FIELD_MAX_Y  = 8'd255;

    // FSM states
    localparam S_IDLE       = 2'd0;
    localparam S_LOAD       = 2'd1;
    localparam S_PROCESS    = 2'd2;
    localparam S_DONE       = 2'd3;

    // ------------------------------------------------------------------------
    // Registers / Memories
    // ------------------------------------------------------------------------
    reg [1:0] state, next_state;

    // store snakes: [7:0]=x, [15:8]=y, [23:16]=d
    reg [23:0] snakes [0:MAX_SNAKES-1];
    reg [4:0]  loaded_count;       // up to 16
    reg [7:0]  snake_cnt_latched;  // latched snake_count

    // Processing control
    reg [3:0]  entry_idx;          // 0..15 (entry candidate index)
    reg [3:0]  exit_idx;           // 0..15 (exit candidate index)
    reg [4:0]  snake_idx;          // 0..16
    reg        path_ok;            // current candidate path viability
    reg        checking;           // indicates active checking for current pair

    // Best result
    reg        found_any;
    reg [7:0]  best_entry_y;
    reg [7:0]  best_exit_y;

    // Latency counter for guaranteed 1024 cycles in PROCESS
    reg [9:0]  proc_cnt;           // 0..1023

    // ------------------------------------------------------------------------
    // Combinational safe-check for single snake vs current candidate path
    // ------------------------------------------------------------------------
    // For simplicity and efficiency, we only check safety at entry (x=0,y=entry_y)
    // and exit (x=255,y=exit_y), i.e., vertical candidate positions on west/east.
    // If both endpoints are safe from all snakes, consider the straight path safe.
    // Uses squared distance vs d^2.

    wire [7:0] cur_entry_y  = {4'b0000, entry_idx} << 4; // 16-step grid: idx*16
    wire [7:0] cur_exit_y   = {4'b0000, exit_idx}  << 4; // 16-step grid: idx*16

    wire [7:0] sx  = snakes[snake_idx][7:0];
    wire [7:0] sy  = snakes[snake_idx][15:8];
    wire [7:0] sd  = snakes[snake_idx][23:16];

    // Entry point (0, cur_entry_y)
    wire signed [9:0] dx_e  = {2'b00, FIELD_MIN_X} - {2'b00, sx};
    wire signed [9:0] dy_e  = {2'b00, cur_entry_y} - {2'b00, sy};
    wire [19:0] dx2_e      = dx_e * dx_e;
    wire [19:0] dy2_e      = dy_e * dy_e;
    wire [19:0] dist2_e    = dx2_e + dy2_e;

    // Exit point (255, cur_exit_y)
    wire signed [9:0] dx_x  = {2'b00, FIELD_MAX_X} - {2'b00, sx};
    wire signed [9:0] dy_x  = {2'b00, cur_exit_y} - {2'b00, sy};
    wire [19:0] dx2_x      = dx_x * dx_x;
    wire [19:0] dy2_x      = dy_x * dy_x;
    wire [19:0] dist2_x    = dx2_x + dy2_x;

    wire [15:0] d2         = sd * sd;

    wire safe_entry_point  = (dist2_e >= d2);
    wire safe_exit_point   = (dist2_x >= d2);
    wire snake_safe_for_pair = safe_entry_point & safe_exit_point;

    // ------------------------------------------------------------------------
    // FSM: Next-state logic
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_LOAD;
            end
            S_LOAD: begin
                if ((loaded_count == snake_cnt_latched) && (snake_cnt_latched <= MAX_SNAKES))
                    next_state = S_PROCESS;
            end
            S_PROCESS: begin
                if (proc_cnt == 10'd1023)
                    next_state = S_DONE;
            end
            S_DONE: begin
                if (!start)
                    next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Sequential logic
    // ------------------------------------------------------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            loaded_count     <= 5'd0;
            snake_cnt_latched<= 8'd0;
            valid_out        <= 1'b0;
            bitten           <= 1'b0;
            entry_exit       <= 16'd0;
            for (i = 0; i < MAX_SNAKES; i = i + 1) begin
                snakes[i] <= 24'd0;
            end
            entry_idx        <= 4'd0;
            exit_idx         <= 4'd0;
            snake_idx        <= 5'd0;
            path_ok          <= 1'b0;
            checking         <= 1'b0;
            found_any        <= 1'b0;
            best_entry_y     <= 8'd0;
            best_exit_y      <= 8'd0;
            proc_cnt         <= 10'd0;
        end else begin
            state <= next_state;

            case (state)
                // ------------------------------------------------------------
                // IDLE
                // ------------------------------------------------------------
                S_IDLE: begin
                    valid_out        <= 1'b0;
                    bitten           <= 1'b0;
                    entry_exit       <= 16'd0;
                    loaded_count     <= 5'd0;
                    proc_cnt         <= 10'd0;
                    entry_idx        <= 4'd0;
                    exit_idx         <= 4'd0;
                    snake_idx        <= 5'd0;
                    path_ok          <= 1'b0;
                    checking         <= 1'b0;
                    found_any        <= 1'b0;
                    best_entry_y     <= 8'd0;
                    best_exit_y      <= 8'd0;
                    if (start) begin
                        snake_cnt_latched <= (snake_count > MAX_SNAKES) ? MAX_SNAKES[7:0] : snake_count;
                    end
                end

                // ------------------------------------------------------------
                // LOAD_SNAKES
                // ------------------------------------------------------------
                S_LOAD: begin
                    valid_out <= 1'b0;
                    bitten    <= 1'b0;
                    // Latch snake data when valid and we still need more
                    if (snake_valid && (loaded_count < snake_cnt_latched) && (loaded_count < MAX_SNAKES)) begin
                        snakes[loaded_count] <= snake_data;
                        loaded_count         <= loaded_count + 5'd1;
                    end

                    // Prepare for PROCESS when done
                    if ((loaded_count == snake_cnt_latched) && (snake_cnt_latched <= MAX_SNAKES)) begin
                        proc_cnt     <= 10'd0;
                        entry_idx    <= 4'd15;  // start from highest (most northerly)
                        exit_idx     <= 4'd15;  // start from highest
                        snake_idx    <= 5'd0;
                        path_ok      <= 1'b1;
                        checking     <= 1'b1;
                        found_any    <= 1'b0;
                        best_entry_y <= 8'd0;
                        best_exit_y  <= 8'd0;
                    end
                end

                // ------------------------------------------------------------
                // PROCESS: Iterate through candidate pairs and snakes
                // Guaranteed to run exactly up to 1024 cycles.
                // ------------------------------------------------------------
                S_PROCESS: begin
                    valid_out <= 1'b0;

                    // Core iteration: one snake check per cycle for current pair
                    if (checking && (snake_idx < snake_cnt_latched)) begin
                        // Update path_ok based on this snake
                        if (path_ok) begin
                            if (!snake_safe_for_pair)
                                path_ok <= 1'b0;
                        end
                        snake_idx <= snake_idx + 5'd1;
                    end else if (checking && (snake_idx >= snake_cnt_latched)) begin
                        // Finished all snakes for this pair
                        checking <= 1'b0;
                        if (path_ok) begin
                            // Candidate pair is safe; record if best (highest entry_y)
                            if (!found_any || (cur_entry_y > best_entry_y) ||
                               ((cur_entry_y == best_entry_y) && (cur_exit_y > best_exit_y))) begin
                                found_any    <= 1'b1;
                                best_entry_y <= cur_entry_y;
                                best_exit_y  <= cur_exit_y;
                            end
                        end
                    end else if (!checking) begin
                        // Move to next candidate pair
                        if (exit_idx != 4'd0) begin
                            exit_idx  <= exit_idx - 4'd1;
                        end else begin
                            exit_idx <= 4'd15;
                            if (entry_idx != 4'd0)
                                entry_idx <= entry_idx - 4'd1;
                        end

                        // Start checking next pair if we still have pairs left
                        if ((entry_idx != 4'd0) || (exit_idx != 4'd0)) begin
                            snake_idx <= 5'd0;
                            path_ok   <= 1'b1;
                            checking  <= 1'b1;
                        end else begin
                            // Last pair (0,0) consumed; no more pairs. Just count cycles.
                            checking <= 1'b0;
                        end
                    end

                    // Cycle counter to enforce 1024-cycle processing window
                    if (proc_cnt != 10'd1023)
                        proc_cnt <= proc_cnt + 10'd1;
                end

                // ------------------------------------------------------------
                // DONE: Output results
                // ------------------------------------------------------------
                S_DONE: begin
                    valid_out <= 1'b1;
                    if (found_any) begin
                        bitten     <= 1'b0; // safe path exists
                        entry_exit <= {best_exit_y, best_entry_y};
                    end else begin
                        bitten     <= 1'b1; // no safe path
                        entry_exit <= 16'd0;
                    end

                    // Wait for start to deassert before going back to IDLE
                    if (!start) begin
                        // prepare for potential next run
                        loaded_count     <= 5'd0;
                        snake_cnt_latched<= 8'd0;
                    end
                end

                default: begin
                    // Should not occur, reset-like behavior
                    state        <= S_IDLE;
                end
            endcase
        end
    end

endmodule