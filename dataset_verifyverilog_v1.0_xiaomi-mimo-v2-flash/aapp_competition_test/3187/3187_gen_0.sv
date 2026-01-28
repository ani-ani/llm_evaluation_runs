module min_total_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] citizen_count,
    input wire [127:0] citizen_x,
    input wire [127:0] citizen_y,
    input wire [15:0] max_dist,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CITIZENS = 3'd1;
    localparam [2:0] BUILD_CANDIDATES_X = 3'd2;
    localparam [2:0] BUILD_CANDIDATES_Y = 3'd3;
    localparam [2:0] CHECK_COMBINATIONS = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    
    // Citizen storage (up to 128, but we only use first 32 for candidates)
    reg [15:0] cx_reg [0:31];
    reg [15:0] cy_reg [0:31];
    
    // Candidate storage
    reg [15:0] cand_x [0:31];
    reg [15:0] cand_y [0:31];
    reg [5:0] num_cand_x;
    reg [5:0] num_cand_y;
    
    // Search indices
    reg [5:0] i, j, k;
    reg [5:0] cx_idx, cy_idx;
    
    // Computation registers
    reg [15:0] total_dist;
    reg [31:0] min_total_dist;
    reg valid_candidate;
    reg [15:0] abs_diff;
    reg [15:0] dist_sum;
    reg [5:0] process_idx;
    reg [7:0] process_count;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Temporary variables for combinational logic
    reg [15:0] temp_x, temp_y;
    reg [15:0] diff_x, diff_y;
    reg found;
    integer m, n;

    // State transition and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all arrays
            for (m = 0; m < 32; m = m + 1) begin
                cx_reg[m] <= 16'd0;
                cy_reg[m] <= 16'd0;
                cand_x[m] <= 16'd0;
                cand_y[m] <= 16'd0;
            end
            num_cand_x <= 6'd0;
            num_cand_y <= 6'd0;
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            cx_idx <= 6'd0;
            cy_idx <= 6'd0;
            total_dist <= 16'd0;
            min_total_dist <= 32'd0;
            valid_candidate <= 1'b0;
            abs_diff <= 16'd0;
            dist_sum <= 16'd0;
            process_idx <= 6'd0;
            process_count <= 8'd0;
            temp_x <= 16'd0;
            temp_y <= 16'd0;
            diff_x <= 16'd0;
            diff_y <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    min_total_dist <= 32'hFFFFFFFF;
                    // Initialize arrays
                    for (m = 0; m < 32; m = m + 1) begin
                        cx_reg[m] <= 16'd0;
                        cy_reg[m] <= 16'd0;
                        cand_x[m] <= 16'd0;
                        cand_y[m] <= 16'd0;
                    end
                    num_cand_x <= 6'd0;
                    num_cand_y <= 6'd0;
                    i <= 6'd0;
                    j <= 6'd0;
                    k <= 6'd0;
                    cx_idx <= 6'd0;
                    cy_idx <= 6'd0;
                    total_dist <= 16'd0;
                    process_idx <= 6'd0;
                    process_count <= 8'd0;
                end
                
                LOAD_CITIZENS: begin
                    // Load up to 32 citizens from packed input
                    if (i < 32 && i < citizen_count) begin
                        cx_reg[i] <= citizen_x[(i * 16) +: 16];
                        cy_reg[i] <= citizen_y[(i * 16) +: 16];
                        i <= i + 6'd1;
                    end else begin
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                    end
                end
                
                BUILD_CANDIDATES_X: begin
                    // Build candidate x from first 32 citizens (simple: take all)
                    if (i < 32 && i < citizen_count) begin
                        cand_x[i] <= cx_reg[i];
                        num_cand_x <= i + 6'd1;
                        i <= i + 6'd1;
                    end else begin
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                    end
                end
                
                BUILD_CANDIDATES_Y: begin
                    // Build candidate y from first 32 citizens (simple: take all)
                    if (i < 32 && i < citizen_count) begin
                        cand_y[i] <= cy_reg[i];
                        num_cand_y <= i + 6'd1;
                        i <= i + 6'd1;
                    end else begin
                        i <= 6'd0;
                        j <= 6'd0;
                        k <= 6'd0;
                    end
                end
                
                CHECK_COMBINATIONS: begin
                    // Reset for each candidate pair
                    if (j == 0 && k == 0) begin
                        valid_candidate <= 1'b1;
                        total_dist <= 16'd0;
                        process_idx <= 6'd0;
                        process_count <= (citizen_count < 128) ? citizen_count : 8'd128;
                    end
                    
                    // Check each citizen against current (cx_idx, cy_idx)
                    if (process_idx < process_count) begin
                        temp_x <= cx_reg[process_idx];
                        temp_y <= cy_reg[process_idx];
                        
                        // Calculate absolute difference
                        if (cand_x[cx_idx] > temp_x) begin
                            diff_x <= cand_x[cx_idx] - temp_x;
                        end else begin
                            diff_x <= temp_x - cand_x[cx_idx];
                        end
                        
                        if (cand_y[cy_idx] > temp_y) begin
                            diff_y <= cand_y[cy_idx] - temp_y;
                        end else begin
                            diff_y <= temp_y - cand_y[cy_idx];
                        end
                        
                        process_idx <= process_idx + 6'd1;
                    end
                    
                    // Add distance if still valid (combinational pipeline)
                    if (process_idx > 0 && valid_candidate) begin
                        total_dist <= total_dist + diff_x + diff_y;
                        if ((diff_x + diff_y) > max_dist) begin
                            valid_candidate <= 1'b0;
                        end
                    end
                    
                    // Move to next citizen or next combination
                    if (process_idx >= process_count && process_idx > 0) begin
                        process_idx <= 6'd0;
                        if (valid_candidate && total_dist + diff_x + diff_y <= min_total_dist) begin
                            // Update min (handle overflow case)
                            if (min_total_dist == 32'hFFFFFFFF) begin
                                min_total_dist <= total_dist + diff_x + diff_y;
                            end else begin
                                min_total_dist <= (total_dist + diff_x + diff_y < min_total_dist) ? (total_dist + diff_x + diff_y) : min_total_dist;
                            end
                        end
                        // Move to next x
                        if (cx_idx + 6'd1 < num_cand_x) begin
                            cx_idx <= cx_idx + 6'd1;
                        end else begin
                            cx_idx <= 6'd0;
                            // Move to next y
                            if (cy_idx + 6'd1 < num_cand_y) begin
                                cy_idx <= cy_idx + 6'd1;
                            end else begin
                                cy_idx <= 6'd0;
                                // All combinations done
                            end
                        end
                    end
                end
                
                UPDATE_RESULT: begin
                    // Final result assignment
                    if (min_total_dist == 32'hFFFFFFFF) begin
                        result <= 32'd0;
                        impossible <= 1'b1;
                    end else begin
                        result <= min_total_dist;
                        impossible <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                    impossible <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_CITIZENS;
                end
            end
            
            LOAD_CITIZENS: begin
                if (i >= 32 || i >= citizen_count) begin
                    next_state = BUILD_CANDIDATES_X;
                end
            end
            
            BUILD_CANDIDATES_X: begin
                if (i >= 32 || i >= citizen_count) begin
                    next_state = BUILD_CANDIDATES_Y;
                end
            end
            
            BUILD_CANDIDATES_Y: begin
                if (i >= 32 || i >= citizen_count) begin
                    next_state = CHECK_COMBINATIONS;
                end
            end
            
            CHECK_COMBINATIONS: begin
                // Check if all combinations are done
                if (cy_idx >= num_cand_y && cx_idx >= num_cand_x) begin
                    next_state = UPDATE_RESULT;
                end
            end
            
            UPDATE_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout check
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
            next_state = DONE_STATE;
        end
    end

endmodule