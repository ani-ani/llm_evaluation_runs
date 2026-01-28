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

// Scaled parameters
parameter MAX_DAYS = 16;
parameter MAX_WORKERS = 8;
parameter MAX_HR = 16;

// Internal state
reg [3:0] stack [0:MAX_WORKERS-1];  // Stack storing HR IDs of hired workers
reg [3:0] sp;  // Stack pointer
reg [3:0] used_hr_mask;  // Bitmask of used HR IDs for current day
reg [3:0] max_hr_used;
reg processing;
reg [3:0] day_counter;

integer i;

// Find smallest available HR ID
function [3:0] find_min_hr(input [15:0] used_mask);
    integer j;
    begin
        find_min_hr = 1;
        for (j = 1; j < MAX_HR; j = j + 1) begin
            if (!used_mask[j] && find_min_hr == 1) begin
                find_min_hr = j;
            end
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sp <= 0;
        max_hr_used <= 0;
        done <= 0;
        processing <= 0;
        day_counter <= 0;
        hr_id <= 0;
        min_hr <= 0;
        for (i = 0; i < MAX_WORKERS; i = i + 1)
            stack[i] <= 0;
    end else begin
        if (start && !processing) begin
            processing <= 1;
            day_counter <= 0;
            done <= 0;
            sp <= 0;
            max_hr_used <= 0;
            for (i = 0; i < MAX_WORKERS; i = i + 1)
                stack[i] <= 0;
        end else if (processing) begin
            if (day_counter < MAX_DAYS) begin
                // Process current day
                used_hr_mask = 0;
                
                // Mark HR IDs of workers being fired
                for (i = 0; i < MAX_WORKERS; i = i + 1) begin
                    if (i < f_i && sp > 0 && sp - 1 - i >= 0) begin
                        used_hr_mask[stack[sp - 1 - i]] = 1;
                    end
                end
                
                // Find available HR ID
                hr_id <= find_min_hr(used_hr_mask);
                
                // Update max HR used
                if (find_min_hr(used_hr_mask) > max_hr_used)
                    max_hr_used <= find_min_hr(used_hr_mask);
                
                // Fire workers (LIFO)
                if (sp >= f_i)
                    sp <= sp - f_i;
                else
                    sp <= 0;
                
                // Hire new workers
                for (i = 0; i < MAX_WORKERS; i = i + 1) begin
                    if (i < h_i && sp + i < MAX_WORKERS) begin
                        stack[sp + i] <= find_min_hr(used_hr_mask);
                    end
                end
                if (sp + h_i <= MAX_WORKERS)
                    sp <= sp + h_i;
                else
                    sp <= MAX_WORKERS;
                
                day_counter <= day_counter + 1;
            end else begin
                processing <= 0;
                done <= 1;
                min_hr <= max_hr_used;
            end
        end else begin
            done <= 0;
        end
    end
end

endmodule