module HRStaffOptimization(
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

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] LOAD      = 4'd1;
    localparam [3:0] POP       = 4'd2;
    localparam [3:0] ASSIGN    = 4'd3;
    localparam [3:0] PUSH      = 4'd4;
    localparam [3:0] UPDATE    = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    reg [3:0] state, next_state;

    // Stack implementation
    reg [15:0] stack [0:511];
    reg [8:0] stack_top;

    // Conflict tracking
    reg [7:0] conflict_flags;

    // Worker ID generation
    reg [15:0] current_worker_id;
    reg [7:0] worker_offset;

    // Day processing
    reg [3:0] current_day;
    reg [7:0] remaining_fires;
    reg [7:0] remaining_hires;

    // HR assignment
    reg [3:0] assigned_hr_id;
    reg [3:0] max_hr_used;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            stack_top <= 9'd0;
            conflict_flags <= 8'd0;
            current_worker_id <= 16'd0;
            worker_offset <= 8'd0;
            current_day <= 4'd0;
            remaining_fires <= 8'd0;
            remaining_hires <= 8'd0;
            assigned_hr_id <= 4'd0;
            max_hr_used <= 4'd0;
            hr_id <= 8'd0;
            min_hr_k <= 4'd0;
            done <= 1'b0;
            stack_overflow <= 2'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    stack_overflow <= 2'd0;
                    if (start) begin
                        next_state <= LOAD;
                        current_day <= day_index;
                        remaining_fires <= f_i;
                        remaining_hires <= h_i;
                        conflict_flags <= 8'd0;
                        cycle_count <= 8'd0;
                    end
                end

                LOAD: begin
                    if (remaining_fires > 8'd0) begin
                        next_state <= POP;
                    end else if (remaining_hires > 8'd0) begin
                        next_state <= PUSH;
                    end else begin
                        next_state <= ASSIGN;
                    end
                end

                POP: begin
                    if (stack_top > 9'd0 && remaining_fires > 8'd0) begin
                        // Pop worker from stack
                        current_worker_id <= stack[stack_top - 1'b1];
                        stack_top <= stack_top - 1'b1;
                        remaining_fires <= remaining_fires - 8'd1;

                        // Extract HR ID from worker ID (bits 15:12)
                        reg [3:0] hire_hr_id;
                        hire_hr_id <= current_worker_id[15:12];

                        // Set conflict flag
                        if (hire_hr_id > 4'd0 && hire_hr_id <= 8'd8) begin
                            conflict_flags[hire_hr_id - 1'b1] <= 1'b1;
                        end

                        if (remaining_fires == 8'd0) begin
                            next_state <= ASSIGN;
                        end
                    end else if (stack_top == 9'd0 && remaining_fires > 8'd0) begin
                        // Stack underflow
                        stack_overflow <= 2'd1;
                        next_state <= IDLE;
                    end else begin
                        next_state <= ASSIGN;
                    end
                end

                ASSIGN: begin
                    // Find smallest available HR ID
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (!conflict_flags[i]) begin
                            assigned_hr_id <= i + 1'b1;
                            break;
                        end
                    end

                    // If all HR IDs conflict, use 1 (shouldn't happen with k<=8)
                    if (assigned_hr_id == 4'd0) begin
                        assigned_hr_id <= 4'd1;
                    end

                    hr_id <= assigned_hr_id;
                    next_state <= PUSH;
                end

                PUSH: begin
                    if (remaining_hires > 8'd0) begin
                        // Generate new worker ID
                        current_worker_id <= {day_index, worker_offset};
                        worker_offset <= worker_offset + 8'd1;

                        // Push to stack
                        if (stack_top < 9'd512) begin
                            stack[stack_top] <= current_worker_id;
                            stack_top <= stack_top + 1'b1;
                            remaining_hires <= remaining_hires - 8'd1;
                        end else begin
                            stack_overflow <= 2'd2;
                            next_state <= IDLE;
                        end

                        if (remaining_hires == 8'd0) begin
                            next_state <= UPDATE;
                        end
                    end else begin
                        next_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Update max HR used
                    if (assigned_hr_id > max_hr_used) begin
                        max_hr_used <= assigned_hr_id;
                    end

                    // Move to next day or finish
                    if (current_day < day_index + 4'd1) begin
                        current_day <= current_day + 4'd1;
                        next_state <= LOAD;
                        remaining_fires <= f_i;
                        remaining_hires <= h_i;
                        conflict_flags <= 8'd0;
                    end else begin
                        min_hr_k <= max_hr_used;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            next_state <= IDLE;
            done <= 1'b1;
            stack_overflow <= 2'd3;
        end
    end

endmodule