module HRStaffOptimization (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] day_index,
    input wire [7:0] f_i,
    input wire [7:0] h_i,
    output reg [7:0] hr_id,
    output reg [3:0] min_hr_k,
    output reg done,
    output reg [1:0] stack_overflow
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_DAY = 3'd1;
    localparam [2:0] POP_FIRED = 3'd2;
    localparam [2:0] ASSIGN_HR = 3'd3;
    localparam [2:0] PUSH_HIRED = 3'd4;
    localparam [2:0] FINISH_DAY = 3'd5;
    localparam [2:0] COMPLETE = 3'd6;

    // Stack parameters
    localparam [8:0] STACK_MAX = 9'd511;
    localparam [4:0] MAX_DAYS = 5'd16;

    // Internal registers
    reg [2:0] state, next_state;
    reg [8:0] stack_top;  // Pointer to next empty slot
    reg [7:0] pop_count;
    reg [7:0] push_count;
    reg [7:0] max_k_reg;
    reg [7:0] conflict_set;  // Bits 1-8, bit 0 unused
    reg [7:0] temp_hr_id;
    reg [7:0] worker_id;  // 16-bit worker ID (packed into 2 bytes for storage)
    reg [7:0] hire_hr_id;  // HR ID that hired this worker
    reg [3:0] current_day;
    reg day_done;
    reg cycle_limit;  // Safety counter
    reg [6:0] cycle_count;
    
    // Stack memory - declared as 2D array for Icarus compatibility
    // Each row: 2 bytes (16-bit worker ID) + 1 byte (hire HR ID) = 24 bits
    // Using separate arrays for compatibility
    reg [15:0] stack_id [0:511];  // Worker IDs
    reg [7:0] stack_hr [0:511];   // HR IDs that hired them

    integer i;

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD_DAY : IDLE;
            LOAD_DAY: next_state = POP_FIRED;
            POP_FIRED: begin
                if (f_i == 8'd0 || pop_count >= f_i)
                    next_state = ASSIGN_HR;
                else if (stack_top == 9'd0 && pop_count < f_i)
                    next_state = ASSIGN_HR;  // Can't pop more, continue
                else
                    next_state = POP_FIRED;
            end
            ASSIGN_HR: next_state = PUSH_HIRED;
            PUSH_HIRED: begin
                if (h_i == 8'd0 || push_count >= h_i)
                    next_state = FINISH_DAY;
                else if (stack_top >= STACK_MAX && push_count < h_i)
                    next_state = FINISH_DAY;  // Stack full, continue
                else
                    next_state = PUSH_HIRED;
            end
            FINISH_DAY: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            stack_top <= 9'd0;
            pop_count <= 8'd0;
            push_count <= 8'd0;
            max_k_reg <= 8'd0;
            conflict_set <= 8'd0;
            temp_hr_id <= 8'd0;
            worker_id <= 8'd0;
            hire_hr_id <= 8'd0;
            current_day <= 4'd0;
            day_done <= 1'b0;
            cycle_limit <= 1'b0;
            cycle_count <= 7'd0;
            hr_id <= 8'd0;
            min_hr_k <= 4'd0;
            done <= 1'b0;
            stack_overflow <= 2'd0;
            
            // Reset stack memory
            for (i = 0; i < 512; i = i + 1) begin
                stack_id[i] <= 16'd0;
                stack_hr[i] <= 8'd0;
            end
        end else begin
            // Reset output flags that should be single cycle
            done <= 1'b0;
            
            // Cycle counter for safety
            if (start) begin
                cycle_count <= 7'd0;
                cycle_limit <= 1'b0;
            end else if (cycle_count < 7'd100) begin
                cycle_count <= cycle_count + 7'd1;
            end else begin
                cycle_limit <= 1'b1;
            end

            // State transitions
            state <= next_state;

            case (state)
                IDLE: begin
                    hr_id <= 8'd0;
                    min_hr_k <= 4'd0;
                    stack_overflow <= 2'd0;
                    current_day <= day_index;
                    day_done <= 1'b0;
                end

                LOAD_DAY: begin
                    pop_count <= 8'd0;
                    push_count <= 8'd0;
                    conflict_set <= 8'd0;
                    temp_hr_id <= 8'd0;
                end

                POP_FIRED: begin
                    if (pop_count < f_i && stack_top > 9'd0 && !cycle_limit) begin
                        // Pop one worker from stack
                        stack_top <= stack_top - 9'd1;
                        pop_count <= pop_count + 8'd1;
                        hire_hr_id <= stack_hr[stack_top - 9'd1];
                        
                        // Set conflict bit for the HR ID that hired this worker
                        if (stack_hr[stack_top - 9'd1] >= 8'd1 && stack_hr[stack_top - 9'd1] <= 8'd8) begin
                            conflict_set[stack_hr[stack_top - 9'd1]] <= 1'b1;
                        end
                    end
                end

                ASSIGN_HR: begin
                    // Find smallest HR ID not in conflict set
                    temp_hr_id <= 8'd0;
                    for (integer j = 1; j <= 8; j = j + 1) begin
                        if (!conflict_set[j] && temp_hr_id == 8'd0) begin
                            temp_hr_id <= j;
                        end
                    end
                    
                    // If all 1-8 are in conflict, use 9 (error case)
                    if (temp_hr_id == 8'd0) begin
                        temp_hr_id <= 8'd9;
                    end
                    
                    // Update max HR ID used
                    if (temp_hr_id > max_k_reg && temp_hr_id <= 8'd8) begin
                        max_k_reg <= temp_hr_id;
                    end
                end

                PUSH_HIRED: begin
                    if (push_count < h_i && stack_top < STACK_MAX && !cycle_limit) begin
                        // Push new worker ID
                        // ID = {day_index[3:0], push_count[3:0]} << 8
                        worker_id <= {current_day[3:0], push_count[3:0]};
                        
                        // Store in stack
                        stack_id[stack_top] <= {current_day[3:0], push_count[3:0], 8'd0};
                        stack_hr[stack_top] <= temp_hr_id;
                        
                        stack_top <= stack_top + 9'd1;
                        push_count <= push_count + 8'd1;
                    end
                    
                    // Set overflow flag if stack full
                    if (push_count < h_i && stack_top >= STACK_MAX) begin
                        stack_overflow <= 2'd1;
                    end
                end

                FINISH_DAY: begin
                    hr_id <= temp_hr_id;
                    day_done <= 1'b1;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    min_hr_k <= max_k_reg[3:0];
                    
                    // Safety: if cycle limit reached, set error
                    if (cycle_limit) begin
                        stack_overflow <= 2'd2;
                    end
                end

                default: begin
                    state <= IDLE;
                    hr_id <= 8'd0;
                    min_hr_k <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule