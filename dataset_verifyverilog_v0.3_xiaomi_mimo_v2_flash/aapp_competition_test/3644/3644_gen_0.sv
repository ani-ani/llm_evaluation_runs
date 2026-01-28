module hr_optimization (
    input clk,
    input rst_n,
    input start,
    input [3:0] day_index,  // Current day (0-15)
    input [3:0] f_i,         // Workers to fire (0-8)
    input [3:0] h_i,         // Workers to hire (0-8)
    output reg [3:0] hr_id,  // Assigned HR ID for this day
    output reg done,         // Computation complete
    output reg [3:0] min_hr  // Minimum HR count needed
);

// State declarations
localparam [2:0] IDLE          = 3'd0;
localparam [2:0] INIT_DAY      = 3'd1;
localparam [2:0] PROCESS_DAY   = 3'd2;
localparam [2:0] UPDATE_STACK  = 3'd3;
localparam [2:0] NEXT_DAY      = 3'd4;
localparam [2:0] FINISH        = 3'd5;

// Parameters
localparam [3:0] MAX_DAYS     = 4'd15;
localparam [3:0] MAX_WORKERS  = 4'd8;
localparam [3:0] MAX_HR       = 4'd15;

// Internal registers
reg [2:0] state, next_state;
reg [3:0] stack [0:7];  // Stack for 8 workers
reg [3:0] sp;           // Stack pointer (0-8)
reg [3:0] used_hr_mask; // Bitmask of used HR IDs (bits 1-15)
reg [3:0] max_hr_used;
reg [3:0] day_counter;
reg [3:0] temp_hr_id;
reg [3:0] fire_counter;
reg [3:0] hire_counter;
reg [3:0] i;  // Loop counter
reg [3:0] j;  // Loop counter

// Function to find smallest available HR ID
function automatic [3:0] find_min_hr(input [15:0] used_mask);
    reg [3:0] k;
    begin
        find_min_hr = 4'd1;
        for (k = 4'd1; k <= MAX_HR; k = k + 4'd1) begin
            if (!used_mask[k] && find_min_hr == 4'd1) begin
                find_min_hr = k;
            end
        end
    end
endfunction

// State transition logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = INIT_DAY;
            else
                next_state = IDLE;
        end
        INIT_DAY: begin
            next_state = PROCESS_DAY;
        end
        PROCESS_DAY: begin
            if (fire_counter < f_i && sp > 4'd0) begin
                next_state = PROCESS_DAY;  // Continue processing fires
            end else begin
                next_state = UPDATE_STACK;
            end
        end
        UPDATE_STACK: begin
            if (hire_counter < h_i && sp < MAX_WORKERS) begin
                next_state = UPDATE_STACK;  // Continue processing hires
            end else begin
                next_state = NEXT_DAY;
            end
        end
        NEXT_DAY: begin
            if (day_counter < MAX_DAYS)
                next_state = INIT_DAY;
            else
                next_state = FINISH;
        end
        FINISH: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        sp <= 4'd0;
        max_hr_used <= 4'd0;
        done <= 1'b0;
        day_counter <= 4'd0;
        hr_id <= 4'd0;
        min_hr <= 4'd0;
        used_hr_mask <= 16'd0;
        temp_hr_id <= 4'd0;
        fire_counter <= 4'd0;
        hire_counter <= 4'd0;
        for (i = 4'd0; i < 4'd8; i = i + 4'd1)
            stack[i] <= 4'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    sp <= 4'd0;
                    max_hr_used <= 4'd0;
                    day_counter <= 4'd0;
                    for (i = 4'd0; i < 4'd8; i = i + 4'd1)
                        stack[i] <= 4'd0;
                end
            end
            
            INIT_DAY: begin
                used_hr_mask <= 16'd0;
                fire_counter <= 4'd0;
                hire_counter <= 4'd0;
            end
            
            PROCESS_DAY: begin
                // Mark HR IDs of workers being fired
                if (fire_counter < f_i && sp > 4'd0) begin
                    if (sp - 4'd1 >= fire_counter) begin
                        used_hr_mask[stack[sp - 4'd1 - fire_counter]] <= 1'b1;
                    end
                    fire_counter <= fire_counter + 4'd1;
                end
            end
            
            UPDATE_STACK: begin
                // Fire workers (LIFO)
                if (fire_counter >= f_i && sp >= f_i)
                    sp <= sp - f_i;
                else if (fire_counter >= f_i)
                    sp <= 4'd0;
                
                // Hire new workers
                if (hire_counter < h_i && sp < MAX_WORKERS) begin
                    temp_hr_id <= find_min_hr(used_hr_mask);
                    used_hr_mask[find_min_hr(used_hr_mask)] <= 1'b1;
                    hire_counter <= hire_counter + 4'd1;
                end else if (hire_counter >= h_i) begin
                    // Update sp after all hires
                    if (sp + h_i <= MAX_WORKERS)
                        sp <= sp + h_i;
                    else
                        sp <= MAX_WORKERS;
                end
            end
            
            NEXT_DAY: begin
                // Calculate HR ID for this day
                hr_id <= temp_hr_id;
                
                // Update max HR used
                if (temp_hr_id > max_hr_used)
                    max_hr_used <= temp_hr_id;
                
                day_counter <= day_counter + 4'd1;
            end
            
            FINISH: begin
                done <= 1'b1;
                min_hr <= max_hr_used;
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
                sp <= 4'd0;
                max_hr_used <= 4'd0;
                day_counter <= 4'd0;
                hr_id <= 4'd0;
                min_hr <= 4'd0;
                for (i = 4'd0; i < 4'd8; i = i + 4'd1)
                    stack[i] <= 4'd0;
            end
        endcase
    end
end

endmodule