module stream_scheduler (
    input clk,
    input rst_n,
    input start,
    input [7:0] s0, d0, p0,
    input [7:0] s1, d1, p1,
    input [7:0] s2, d2, p2,
    input [7:0] s3, d3, p3,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    reg [2:0] state, next_state;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Input storage registers (unpacked array for clarity, but accessed individually)
    reg [7:0] start_reg [0:3];
    reg [7:0] dur_reg [0:3];
    reg [7:0] prio_reg [0:3];
    wire [15:0] end_time [0:3];
    
    // Compute end times
    assign end_time[0] = {8'd0, start_reg[0]} + {8'd0, dur_reg[0]};
    assign end_time[1] = {8'd0, start_reg[1]} + {8'd0, dur_reg[1]};
    assign end_time[2] = {8'd0, start_reg[2]} + {8'd0, dur_reg[2]};
    assign end_time[3] = {8'd0, start_reg[3]} + {8'd0, dur_reg[3]};

    // Subset iteration variables
    reg [3:0] subset_idx;      // 0 to 15
    reg [15:0] current_prio_sum;
    reg feasible;
    wire [15:0] new_priority;
    
    // Helper variables for intersection checking
    reg [1:0] i, j;
    reg intersect;
    reg [7:0] s_i, s_j;
    reg [15:0] e_i, e_j;

    // New priority for current subset
    assign new_priority = current_prio_sum;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                if (subset_idx < 4'd15)
                    next_state = COMPUTE;  // Continue to next subset
                else
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and state register logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            subset_idx <= 4'd0;
            current_prio_sum <= 16'd0;
            feasible <= 1'b0;
            i <= 2'd0;
            j <= 2'd0;
            intersect <= 1'b0;
            s_i <= 8'd0;
            s_j <= 8'd0;
            e_i <= 16'd0;
            e_j <= 16'd0;
            start_reg[0] <= 8'd0; start_reg[1] <= 8'd0; start_reg[2] <= 8'd0; start_reg[3] <= 8'd0;
            dur_reg[0] <= 8'd0; dur_reg[1] <= 8'd0; dur_reg[2] <= 8'd0; dur_reg[3] <= 8'd0;
            prio_reg[0] <= 8'd0; prio_reg[1] <= 8'd0; prio_reg[2] <= 8'd0; prio_reg[3] <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            // Cycle counter increment (only when not IDLE or DONE to prevent wraparound)
            if (state != IDLE && state != DONE && state != LOAD) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    subset_idx <= 4'd0;
                    current_prio_sum <= 16'd0;
                    feasible <= 1'b0;
                    i <= 2'd0;
                    j <= 2'd0;
                    // Keep result persistent
                end
                
                LOAD: begin
                    // Load all inputs into registers
                    start_reg[0] <= s0;
                    dur_reg[0] <= d0;
                    prio_reg[0] <= p0;
                    
                    start_reg[1] <= s1;
                    dur_reg[1] <= d1;
                    prio_reg[1] <= p1;
                    
                    start_reg[2] <= s2;
                    dur_reg[2] <= d2;
                    prio_reg[2] <= p2;
                    
                    start_reg[3] <= s3;
                    dur_reg[3] <= d3;
                    prio_reg[3] <= p3;
                    
                    // Reset subset iteration
                    subset_idx <= 4'd0;
                    // Reset result for new computation
                    result <= 16'd0;
                end
                
                COMPUTE: begin
                    // Calculate priority sum and feasibility for current subset
                    current_prio_sum <= 16'd0;
                    feasible <= 1'b1;  // Assume feasible initially
                    i <= 2'd0;
                    j <= 2'd0;
                    
                    // Check which streams are in subset and sum priorities
                    if (subset_idx[0]) current_prio_sum <= current_prio_sum + {8'd0, prio_reg[0]};
                    if (subset_idx[1]) current_prio_sum <= current_prio_sum + {8'd0, prio_reg[1]};
                    if (subset_idx[2]) current_prio_sum <= current_prio_sum + {8'd0, prio_reg[2]};
                    if (subset_idx[3]) current_prio_sum <= current_prio_sum + {8'd0, prio_reg[3]};
                    
                    // Intersection checking logic (combinational)
                    intersect <= 1'b0;
                    s_i <= 8'd0;
                    s_j <= 8'd0;
                    e_i <= 16'd0;
                    e_j <= 16'd0;
                end
                
                UPDATE: begin
                    // Check intersection for all pairs
                    // We need a combinatorial check, but since this is sequential,
                    // we check pairs one by one per cycle to keep logic simple
                    
                    // For current subset, check all pairs
                    // If any pair intersects and both are in subset, mark infeasible
                    
                    // Pair (0,1)
                    if (subset_idx[0] && subset_idx[1]) begin
                        // Check crossing: (s0 < s1 < e0 < e1) OR (s1 < s0 < e1 < e0)
                        if ((start_reg[0] < start_reg[1]) && (start_reg[1] < end_time[0]) && (end_time[0] < end_time[1])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[1] < start_reg[0]) && (start_reg[0] < end_time[1]) && (end_time[1] < end_time[0])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Pair (0,2)
                    if (feasible && subset_idx[0] && subset_idx[2]) begin
                        if ((start_reg[0] < start_reg[2]) && (start_reg[2] < end_time[0]) && (end_time[0] < end_time[2])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[2] < start_reg[0]) && (start_reg[0] < end_time[2]) && (end_time[2] < end_time[0])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Pair (0,3)
                    if (feasible && subset_idx[0] && subset_idx[3]) begin
                        if ((start_reg[0] < start_reg[3]) && (start_reg[3] < end_time[0]) && (end_time[0] < end_time[3])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[3] < start_reg[0]) && (start_reg[0] < end_time[3]) && (end_time[3] < end_time[0])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Pair (1,2)
                    if (feasible && subset_idx[1] && subset_idx[2]) begin
                        if ((start_reg[1] < start_reg[2]) && (start_reg[2] < end_time[1]) && (end_time[1] < end_time[2])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[2] < start_reg[1]) && (start_reg[1] < end_time[2]) && (end_time[2] < end_time[1])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Pair (1,3)
                    if (feasible && subset_idx[1] && subset_idx[3]) begin
                        if ((start_reg[1] < start_reg[3]) && (start_reg[3] < end_time[1]) && (end_time[1] < end_time[3])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[3] < start_reg[1]) && (start_reg[1] < end_time[3]) && (end_time[3] < end_time[1])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Pair (2,3)
                    if (feasible && subset_idx[2] && subset_idx[3]) begin
                        if ((start_reg[2] < start_reg[3]) && (start_reg[3] < end_time[2]) && (end_time[2] < end_time[3])) begin
                            feasible <= 1'b0;
                        end else if ((start_reg[3] < start_reg[2]) && (start_reg[2] < end_time[3]) && (end_time[3] < end_time[2])) begin
                            feasible <= 1'b0;
                        end
                    end
                    
                    // Update max if feasible and better
                    if (feasible && new_priority > result) begin
                        result <= new_priority;
                    end
                    
                    // Move to next subset
                    subset_idx <= subset_idx + 4'd1;
                end
                
                DONE: begin
                    done <= 1'b1;
                    // result is already set
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

endmodule