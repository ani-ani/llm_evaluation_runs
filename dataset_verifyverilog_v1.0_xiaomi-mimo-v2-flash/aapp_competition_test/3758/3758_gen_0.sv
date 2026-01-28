module FindMinTime(
    input clk,
    input rst_n,
    input start,
    input [3:0] field [0:15],
    output reg [7:0] result,
    output reg done,
    output reg busy
);

// State declarations
localparam [2:0] IDLE       = 3'd0;
localparam [2:0] INIT_SEARCH = 3'd1;
localparam [2:0] CHECK_TIME  = 3'd2;
localparam [2:0] UPDATE_BOUND = 3'd3;
localparam [2:0] FINISH      = 3'd4;

reg [2:0] state, next_state;

// Binary search variables
reg [7:0] low, next_low;
reg [7:0] high, next_high;
reg [7:0] mid, next_mid;
reg [7:0] candidate, next_candidate;

// Counter for packing positions
reg [3:0] idx, next_idx;

// Packed positions
reg [3:0] packmen [0:15];  // Up to 16 packmen
reg [3:0] asterisks [0:15]; // Up to 16 asterisks
reg [3:0] num_packmen, next_num_packmen;
reg [3:0] num_asterisks, next_num_asterisks;

// Check logic variables (combinational)
reg [3:0] check_packmen [0:15];
reg [3:0] check_asterisks [0:15];
reg [3:0] check_num_packmen;
reg [3:0] check_num_asterisks;
reg [7:0] check_time;
reg check_feasible;

// Cycle counter for timeout protection
reg [9:0] cycle_counter, next_cycle_counter;
localparam [9:0] MAX_CYCLES = 10'd512;

// Internal FSM variables
reg [1:0] sub_state, next_sub_state;
localparam [1:0] SUB_IDLE     = 2'd0;
localparam [1:0] SUB_PACK     = 2'd1;
localparam [1:0] SUB_ASTER    = 2'd2;
localparam [1:0] SUB_CHECK    = 2'd3;

// Check FSM variables
reg [3:0] p_idx, next_p_idx;
reg [3:0] a_ptr, next_a_ptr;
reg [7:0] time_used, next_time_used;
reg check_done, next_check_done;
reg check_result, next_check_result;

integer i;

// Main FSM - sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        low <= 8'd0;
        high <= 8'd255;
        mid <= 8'd0;
        candidate <= 8'd0;
        idx <= 4'd0;
        num_packmen <= 4'd0;
        num_asterisks <= 4'd0;
        cycle_counter <= 10'd0;
        sub_state <= SUB_IDLE;
        p_idx <= 4'd0;
        a_ptr <= 4'd0;
        time_used <= 8'd0;
        check_done <= 1'b0;
        check_result <= 1'b0;
        busy <= 1'b0;
        done <= 1'b0;
        result <= 8'd0;
        for (i = 0; i < 16; i = i + 1) begin
            packmen[i] <= 4'd0;
            asterisks[i] <= 4'd0;
            check_packmen[i] <= 4'd0;
            check_asterisks[i] <= 4'd0;
        end
    end else begin
        state <= next_state;
        low <= next_low;
        high <= next_high;
        mid <= next_mid;
        candidate <= next_candidate;
        idx <= next_idx;
        num_packmen <= next_num_packmen;
        num_asterisks <= next_num_asterisks;
        cycle_counter <= next_cycle_counter;
        sub_state <= next_sub_state;
        p_idx <= next_p_idx;
        a_ptr <= next_a_ptr;
        time_used <= next_time_used;
        check_done <= next_check_done;
        check_result <= next_check_result;
        busy <= (next_state != IDLE && next_state != FINISH);
        done <= (next_state == FINISH);
        if (next_state == FINISH) begin
            result <= candidate;
        end
        // Update packed arrays during packing phase
        if (sub_state == SUB_PACK && idx < 4'd16) begin
            if (field[idx] == 4'd2) begin
                packmen[num_packmen] <= idx;
                num_packmen <= num_packmen + 4'd1;
            end
            idx <= idx + 4'd1;
        end
        if (sub_state == SUB_ASTER && idx < 4'd16) begin
            if (field[idx] == 4'd1) begin
                asterisks[num_asterisks] <= idx;
                num_asterisks <= num_asterisks + 4'd1;
            end
            idx <= idx + 4'd1;
        end
    end
end

// Combinational logic for checking feasibility
always @(*) begin
    // Default values
    for (i = 0; i < 16; i = i + 1) begin
        check_packmen[i] = packmen[i];
        check_asterisks[i] = asterisks[i];
    end
    check_num_packmen = num_packmen;
    check_num_asterisks = num_asterisks;
    check_time = candidate;
    
    // Check logic
    check_feasible = 1'b1;
    if (check_num_asterisks == 4'd0) begin
        check_feasible = 1'b1; // No asterisks to eat
    end else if (check_num_packmen == 4'd0) begin
        check_feasible = 1'b0; // No packmen to eat
    end else begin
        // Simulate greedy eating
        reg [3:0] current_asterisk;
        reg [3:0] asterisk_idx;
        reg [7:0] dist;
        
        asterisk_idx = 4'd0; // Next uneaten asterisk index
        
        for (i = 0; i < 16; i = i + 1) begin
            // Process each packman in order
            if (i < check_num_packmen && asterisk_idx < check_num_asterisks) begin
                // Packman can eat multiple asterisks if they are close
                reg can_eat;
                reg [3:0] next_asterisk_idx;
                
                next_asterisk_idx = asterisk_idx;
                can_eat = 1'b1;
                
                while (can_eat && next_asterisk_idx < check_num_asterisks) begin
                    // Calculate distance
                    if (check_packmen[i] >= check_asterisks[next_asterisk_idx]) begin
                        dist = check_packmen[i] - check_asterisks[next_asterisk_idx];
                    end else begin
                        dist = check_asterisks[next_asterisk_idx] - check_packmen[i];
                    end
                    
                    if (dist <= check_time) begin
                        // Can eat this one, move to next
                        next_asterisk_idx = next_asterisk_idx + 4'd1;
                    end else begin
                        // Cannot eat this one
                        can_eat = 1'b0;
                    end
                end
                
                asterisk_idx = next_asterisk_idx;
            end
        end
        
        // Check if all asterisks eaten
        check_feasible = (asterisk_idx >= check_num_asterisks);
    end
end

// Next state logic
always @(*) begin
    // Defaults
    next_state = state;
    next_low = low;
    next_high = high;
    next_mid = mid;
    next_candidate = candidate;
    next_idx = idx;
    next_num_packmen = num_packmen;
    next_num_asterisks = num_asterisks;
    next_cycle_counter = cycle_counter;
    next_sub_state = sub_state;
    next_p_idx = p_idx;
    next_a_ptr = a_ptr;
    next_time_used = time_used;
    next_check_done = check_done;
    next_check_result = check_result;

    case (state)
        IDLE: begin
            next_idx = 4'd0;
            next_num_packmen = 4'd0;
            next_num_asterisks = 4'd0;
            next_cycle_counter = 10'd0;
            next_sub_state = SUB_IDLE;
            if (start) begin
                next_state = INIT_SEARCH;
                next_sub_state = SUB_PACK;
            end
        end

        INIT_SEARCH: begin
            // Packing phase
            case (sub_state)
                SUB_PACK: begin
                    if (idx >= 4'd16) begin
                        next_idx = 4'd0;
                        next_sub_state = SUB_ASTER;
                    end
                end
                SUB_ASTER: begin
                    if (idx >= 4'd16) begin
                        next_idx = 4'd0;
                        // Initialize binary search bounds
                        next_low = 8'd0;
                        next_high = 8'd255;
                        next_sub_state = SUB_IDLE;
                        next_state = CHECK_TIME;
                    end
                end
                default: begin
                    next_state = CHECK_TIME;
                end
            endcase
        end

        CHECK_TIME: begin
            // Perform binary search: mid = (low + high) / 2
            next_mid = (low + high) >> 1;
            next_candidate = (low + high) >> 1;
            next_state = UPDATE_BOUND;
        end

        UPDATE_BOUND: begin
            next_cycle_counter = cycle_counter + 10'd1;
            
            // Use the combinational check_feasible signal
            if (check_feasible) begin
                // Time is feasible, try smaller time
                next_high = candidate;
            end else begin
                // Time not feasible, try larger time
                next_low = candidate + 8'd1;
            end
            
            // Check convergence or timeout
            if (next_low >= next_high || cycle_counter >= MAX_CYCLES) begin
                next_candidate = next_low;
                next_state = FINISH;
            end else begin
                next_state = CHECK_TIME;
            end
        end

        FINISH: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule