module TorpedoPathfinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [7:0] m,
    input wire [15:0] ship_x1,
    input wire [15:0] ship_x2,
    input wire [15:0] ship_y,
    input wire ship_write,
    input wire [4:0] ship_idx,
    output reg [63:0] result,
    output reg possible,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SHIP_LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] RECONSTRUCT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] ship_counter;
    reg [5:0] y_counter;
    reg [3:0] x_index;
    reg [4:0] current_ship_idx;
    reg [15:0] current_n;
    reg [7:0] current_m;
    reg [15:0] ship_x1_reg [0:15];
    reg [15:0] ship_x2_reg [0:15];
    reg [15:0] ship_y_reg [0:15];
    reg [15:0] reachable [0:63];
    reg [15:0] parent [0:63];
    reg [7:0] path [0:63];
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            ship_counter <= 5'd0;
            y_counter <= 6'd0;
            x_index <= 4'd0;
            current_ship_idx <= 5'd0;
            current_n <= 16'd0;
            current_m <= 8'd0;
            done <= 1'b0;
            possible <= 1'b0;
            result <= 64'd0;
            cycle_count <= 6'd0;

            // Initialize ship registers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                ship_x1_reg[i] <= 16'd0;
                ship_x2_reg[i] <= 16'd0;
                ship_y_reg[i] <= 16'd0;
            end

            // Initialize reachability and parent arrays
            for (i = 0; i < 64; i = i + 1) begin
                reachable[i] <= 16'd0;
                parent[i] <= 16'd0;
                path[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Ship loading state
    always @(posedge clk) begin
        if (state == SHIP_LOAD && ship_write) begin
            if (ship_idx < 16) begin
                ship_x1_reg[ship_idx] <= ship_x1;
                ship_x2_reg[ship_idx] <= ship_x2;
                ship_y_reg[ship_idx] <= ship_y;
                ship_counter <= ship_counter + 1'b1;
            end
        end
    end

    // Main state machine
    always @(posedge clk) begin
        if (state == IDLE) begin
            if (start) begin
                next_state <= SHIP_LOAD;
                current_n <= n;
                current_m <= m;
                ship_counter <= 5'd0;
            end
        end else if (state == SHIP_LOAD) begin
            if (ship_counter >= current_m) begin
                next_state <= COMPUTE;
                y_counter <= 6'd0;
                reachable[0] <= 16'h0001;  // Start at x_index 8 (x=0)
                parent[0] <= 16'd0;
            end
        end else if (state == COMPUTE) begin
            if (y_counter < current_n && y_counter < 64) begin
                // Compute next reachable positions
                reg [15:0] next_reachable;
                reg [15:0] temp_reachable;
                integer i;

                // Left diagonal move (x-1)
                temp_reachable = reachable[y_counter] << 1;
                temp_reachable = temp_reachable & 16'hFFFE;  // Prevent overflow
                next_reachable = temp_reachable;

                // Vertical move (x)
                next_reachable = next_reachable | reachable[y_counter];

                // Right diagonal move (x+1)
                temp_reachable = reachable[y_counter] >> 1;
                next_reachable = next_reachable | temp_reachable;

                // Apply ship obstructions
                for (i = 0; i < current_m; i = i + 1) begin
                    if (ship_y_reg[i] == y_counter + 1) begin
                        reg [15:0] mask;
                        reg [15:0] x1_index, x2_index;
                        reg [15:0] temp_x1, temp_x2;

                        // Convert ship coordinates to x_index
                        temp_x1 = ship_x1_reg[i] + 16'd8;
                        temp_x2 = ship_x2_reg[i] + 16'd8;

                        // Clamp to valid range
                        if (temp_x1 < 16'd0) temp_x1 = 16'd0;
                        if (temp_x1 > 16'd15) temp_x1 = 16'd15;
                        if (temp_x2 < 16'd0) temp_x2 = 16'd0;
                        if (temp_x2 > 16'd15) temp_x2 = 16'd15;

                        x1_index = temp_x1;
                        x2_index = temp_x2;

                        // Create mask for blocked positions
                        if (x1_index <= x2_index) begin
                            mask = 16'd0;
                            for (i = x1_index; i <= x2_index; i = i + 1) begin
                                mask = mask | (1 << i);
                            end
                            next_reachable = next_reachable & ~mask;
                        end
                    end
                end

                reachable[y_counter + 1] <= next_reachable;
                parent[y_counter + 1] <= reachable[y_counter];
                y_counter <= y_counter + 1'b1;
            end else begin
                next_state <= RECONSTRUCT;
                y_counter <= current_n - 1;
            end
        end else if (state == RECONSTRUCT) begin
            if (reachable[current_n - 1] != 16'd0) begin
                possible <= 1'b1;
                // Reconstruct path
                reg [3:0] current_x;
                integer i;

                // Find any reachable position at final y
                for (i = 0; i < 16; i = i + 1) begin
                    if (reachable[current_n - 1][i]) begin
                        current_x = i;
                        break;
                    end
                end

                // Backtrack to build path
                for (i = current_n - 1; i > 0; i = i - 1) begin
                    reg [3:0] parent_x;
                    // Find parent position
                    for (parent_x = 0; parent_x < 16; parent_x = parent_x + 1) begin
                        if (parent[i][parent_x] && 
                            ((parent_x == current_x - 1) || 
                             (parent_x == current_x) ||
                             (parent_x == current_x + 1))) begin
                            break;
                        end
                    end

                    // Determine movement
                    if (parent_x == current_x - 1) begin
                        path[i] <= 8'd45;  // '-'
                    end else if (parent_x == current_x) begin
                        path[i] <= 8'd48;  // '0'
                    end else if (parent_x == current_x + 1) begin
                        path[i] <= 8'd43;  // '+'
                    end

                    current_x = parent_x;
                end

                // Build result
                for (i = 0; i < current_n; i = i + 1) begin
                    result[(i+1)*8-1:i*8] <= path[i];
                end
            end else begin
                possible <= 1'b0;
            end
            next_state <= DONE_STATE;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
            next_state <= IDLE;
        end
    end

    // Cycle counter for timeout
    always @(posedge clk) begin
        if (state != IDLE && state != DONE_STATE) begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1'b1;
            end else begin
                // Timeout - force to done state
                next_state <= DONE_STATE;
                possible <= 1'b0;
            end
        end else begin
            cycle_count <= 6'd0;
        end
    end

endmodule