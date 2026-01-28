module MinimumCostMatching(
    input clk,
    input rst_n,
    input start,
    input [31:0] springs,
    input [31:0] towns,
    input [63:0] hill_x,
    input [63:0] hill_y,
    input [63:0] hill_h,
    input [7:0] max_len,
    output reg [23:0] result,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT          = 4'd1;
    localparam [3:0] BUILD_MATRIX  = 4'd2;
    localparam [3:0] HUNGARIAN     = 4'd3;
    localparam [3:0] CALC_SUM      = 4'd4;
    localparam [3:0] FINISH        = 4'd5;
    localparam [3:0] IMPOSSIBLE_STATE = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Matrix storage (16x16 max, Q8.16 format)
    reg [23:0] cost_matrix [0:15][0:15];
    reg [23:0] u [0:15];  // Row potentials
    reg [23:0] v [0:15];  // Column potentials
    reg [3:0] match_row [0:15];  // What column is matched to row i
    reg [3:0] match_col [0:15];  // What row is matched to column j
    reg [23:0] slack [0:15];
    reg [3:0] slack_row [0:15];
    
    // Counters and indices
    reg [3:0] i, j, k, iter;
    reg [3:0] num_springs, num_towns;
    reg [3:0] row, col;
    reg [3:0] s_col, t_row;
    
    // Flags
    reg found;
    reg all_valid;
    reg perfect_match;
    
    // Temporary values for calculations
    reg [15:0] dx, dy, dh;
    reg [31:0] dist_sq;
    reg [15:0] dist_approx;
    reg [23:0] temp_cost;
    reg [23:0] max_len_scaled;
    
    // For Hungarian algorithm
    reg [23:0] min_slack;
    reg [23:0] delta;
    reg [23:0] diff;
    reg [23:0] new_val;
    
    // Array index calculations
    wire [3:0] spring_idx [0:15];
    wire [3:0] town_idx [0:15];
    wire [7:0] hill_x_val [0:15];
    wire [7:0] hill_y_val [0:15];
    wire [7:0] hill_h_val [0:15];
    
    // Unpack inputs
    genvar g;
    generate
        for (g = 0; g < 16; g = g + 1) begin : unpack_inputs
            assign spring_idx[g] = springs[4*g +: 4];
            assign town_idx[g] = towns[4*g +: 4];
            assign hill_x_val[g] = hill_x[8*g +: 8];
            assign hill_y_val[g] = hill_y[8*g +: 8];
            assign hill_h_val[g] = hill_h[8*g +: 8];
        end
    endgenerate

    // Calculate approximate distance using shift-add (sqrt approximation)
    function [15:0] approx_sqrt;
        input [31:0] value;
        reg [15:0] root;
        reg [31:0] rem;
        reg [15:0] term;
        integer b;
        begin
            root = 16'd0;
            rem = value;
            for (b = 14; b >= 0; b = b - 1) begin
                term = (root << 1) | (16'd1 << b);
                if ((term * term) <= rem) begin
                    root = root | (16'd1 << b);
                    rem = rem - (term * term);
                end
            end
            // Shift right by 4 for scaling (Q4.0 to Q4.4)
            approx_sqrt = root >> 4;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            iter <= 4'd0;
            num_springs <= 4'd0;
            num_towns <= 4'd0;
            row <= 4'd0;
            col <= 4'd0;
            s_col <= 4'd0;
            t_row <= 4'd0;
            found <= 1'b0;
            all_valid <= 1'b0;
            perfect_match <= 1'b0;
            max_len_scaled <= 24'd0;
            // Initialize all matrix elements to 0
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    cost_matrix[i][j] <= 24'd0;
                end
            end
            for (i = 0; i < 16; i = i + 1) begin
                u[i] <= 24'd0;
                v[i] <= 24'd0;
                match_row[i] <= 4'd0;
                match_col[i] <= 4'd0;
                slack[i] <= 24'd0;
                slack_row[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    result <= 24'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Count springs and towns
                    num_springs <= 4'd0;
                    num_towns <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (spring_idx[i] != 4'd0 || i == 0) begin
                            num_springs <= num_springs + 4'd1;
                        end
                        if (town_idx[i] != 4'd0 || i == 0) begin
                            num_towns <= num_towns + 4'd1;
                        end
                    end
                    // Check if t <= s
                    if (num_towns > num_springs) begin
                        state <= IMPOSSIBLE_STATE;
                    end else begin
                        max_len_scaled <= {16'd0, max_len} << 4;  // Q8.16 format
                        state <= BUILD_MATRIX;
                        row <= 4'd0;
                        col <= 4'd0;
                    end
                end
                
                BUILD_MATRIX: begin
                    // Build cost matrix
                    if (row < num_springs) begin
                        if (col < num_towns) begin
                            // Get hill indices
                            s_col <= spring_idx[row];
                            t_row <= town_idx[col];
                            // Calculate distance
                            dx <= (hill_x_val[spring_idx[row]] > hill_x_val[town_idx[col]]) ? 
                                  (hill_x_val[spring_idx[row]] - hill_x_val[town_idx[col]]) : 
                                  (hill_x_val[town_idx[col]] - hill_x_val[spring_idx[row]]);
                            dy <= (hill_y_val[spring_idx[row]] > hill_y_val[town_idx[col]]) ? 
                                  (hill_y_val[spring_idx[row]] - hill_y_val[town_idx[col]]) : 
                                  (hill_y_val[town_idx[col]] - hill_y_val[spring_idx[row]]);
                            dh <= (hill_h_val[spring_idx[row]] > hill_h_val[town_idx[col]]) ? 
                                  (hill_h_val[spring_idx[row]] - hill_h_val[town_idx[col]]) : 
                                  (hill_h_val[town_idx[col]] - hill_h_val[spring_idx[row]]);
                            // Height constraint: spring_h > town_h
                            if (hill_h_val[spring_idx[row]] <= hill_h_val[town_idx[col]]) begin
                                cost_matrix[row][col] <= 24'hFFFFFF;  // INF
                            end else begin
                                // Calculate squared distance (scaled by 10000)
                                dist_sq <= (dx * dx + dy * dy);
                                // Check if we need to compute sqrt next cycle
                                state <= BUILD_MATRIX;
                                col <= col + 4'd1;
                                // After distance calculation, set cost
                                temp_cost <= approx_sqrt(dx * dx + dy * dy) * 10;  // Scale to Q8.16
                                if (temp_cost > max_len_scaled) begin
                                    cost_matrix[row][col] <= 24'hFFFFFF;
                                end else begin
                                    cost_matrix[row][col] <= temp_cost;
                                end
                            end
                        end else begin
                            // Pad remaining columns with INF
                            for (k = num_towns; k < 16; k = k + 1) begin
                                cost_matrix[row][k] <= 24'hFFFFFF;
                            end
                            col <= 4'd0;
                            row <= row + 4'd1;
                        end
                    end else begin
                        // Pad remaining rows
                        for (k = num_springs; k < 16; k = k + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                cost_matrix[k][j] <= 24'hFFFFFF;
                            end
                        end
                        // Check if all towns have valid connections
                        all_valid <= 1'b1;
                        for (t_row = 0; t_row < num_towns; t_row = t_row + 1) begin
                            found <= 1'b0;
                            for (s_col = 0; s_col < num_springs; s_col = s_col + 1) begin
                                if (cost_matrix[s_col][t_row] != 24'hFFFFFF) begin
                                    found <= 1'b1;
                                end
                            end
                            if (!found) begin
                                all_valid <= 1'b0;
                            end
                        end
                        if (!all_valid) begin
                            state <= IMPOSSIBLE_STATE;
                        end else begin
                            state <= HUNGARIAN;
                            iter <= 4'd0;
                        end
                    end
                end
                
                HUNGARIAN: begin
                    // Hungarian algorithm implementation
                    // Initialize potentials to 0
                    if (iter == 4'd0) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            u[i] <= 24'd0;
                            v[i] <= 24'd0;
                            match_row[i] <= 4'd15;  // No match
                            match_col[i] <= 4'd15;
                        end
                        iter <= 4'd1;
                    end else if (iter <= num_springs) begin
                        // For each row
                        row <= iter - 4'd1;
                        // Initialize slack
                        for (j = 0; j < 16; j = j + 1) begin
                            slack[j] <= cost_matrix[iter - 4'd1][j] - u[iter - 4'd1] - v[j];
                            slack_row[j] <= iter - 4'd1;
                        end
                        // Find augmenting path
                        found <= 1'b0;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (!found && match_col[k] == 4'd15 && slack[k] == 24'd0) begin
                                found <= 1'b1;
                                // Try to match
                                match_row[iter - 4'd1] <= k;
                                match_col[k] <= iter - 4'd1;
                            end
                        end
                        if (!found) begin
                            // Update potentials
                            min_slack <= 24'hFFFFFF;
                            for (j = 0; j < 16; j = j + 1) begin
                                if (match_col[j] == 4'd15 && slack[j] < min_slack) begin
                                    min_slack <= slack[j];
                                end
                            end
                            delta <= min_slack;
                            // Update u and v
                            for (i = 0; i < 16; i = i + 1) begin
                                if (match_row[i] != 4'd15) begin
                                    u[i] <= u[i] + min_slack;
                                end
                            end
                            for (j = 0; j < 16; j = j + 1) begin
                                v[j] <= v[j] - min_slack;
                                if (match_col[j] == 4'd15) begin
                                    slack[j] <= slack[j] - min_slack;
                                end
                            end
                            // Find augmenting path again
                            found <= 1'b0;
                            for (k = 0; k < 16; k = k + 1) begin
                                if (!found && match_col[k] == 4'd15 && slack[k] == 24'd0) begin
                                    found <= 1'b1;
                                    match_row[iter - 4'd1] <= k;
                                    match_col[k] <= iter - 4'd1;
                                end
                            end
                        end
                        iter <= iter + 4'd1;
                    end else begin
                        // Check if perfect match exists
                        perfect_match <= 1'b1;
                        for (i = 0; i < num_towns; i = i + 1) begin
                            if (match_col[i] == 4'd15) begin
                                perfect_match <= 1'b0;
                            end
                        end
                        if (!perfect_match) begin
                            state <= IMPOSSIBLE_STATE;
                        end else begin
                            state <= CALC_SUM;
                            result <= 24'd0;
                            i <= 4'd0;
                        end
                    end
                end
                
                CALC_SUM: begin
                    // Sum the costs of the matching
                    if (i < num_towns) begin
                        // Add cost_matrix[match_col[i]][i]
                        result <= result + cost_matrix[match_col[i]][i];
                        i <= i + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                IMPOSSIBLE_STATE: begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != FINISH && state != IMPOSSIBLE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= IMPOSSIBLE_STATE;
                end
            end
        end
    end

endmodule