module pharmacy (
    input clk, rst_n, start,
    input load_enable,
    input [31:0] load_drop_time,
    input load_type,           // 1 for S, 0 for R
    input [8:0] load_fill_time,
    input load_done,
    output reg [63:0] sum_S,   // Sum of completion times for in-store
    output reg [63:0] sum_R,   // Sum of completion times for remote
    output reg [31:0] count_S, // Count of in-store prescriptions
    output reg [31:0] count_R, // Count of remote prescriptions
    output reg done
);

// Parameters
parameter N = 16;  // Max prescriptions
parameter T = 4;   // Max technicians

// Internal registers for prescription data
reg [31:0] drop_time [0:N-1];
reg type_reg [0:N-1];           // 1 for S, 0 for R
reg [8:0] fill_time [0:N-1];
reg [4:0] load_count;           // Number of loaded prescriptions

// State machine
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] SORT = 3'd2;
localparam [2:0] SCHEDULE = 3'd3;
localparam [2:0] DONE = 3'd4;
reg [2:0] state, next_state;

// Sorting state
reg [4:0] sort_pass;
reg [4:0] sort_index;
reg sort_swapped;

// Scheduling state
reg [4:0] sched_index;          // Current prescription in sorted list
reg [31:0] tech_free_time [0:T-1]; // When each technician is free
reg [31:0] min_free_time;      // Minimum free time
reg [1:0] min_tech;            // Technician with min free time

// Helper signals
integer i;
reg [31:0] completion_time;
reg [31:0] delay;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        sum_S <= 64'd0;
        sum_R <= 64'd0;
        count_S <= 32'd0;
        count_R <= 32'd0;
        done <= 1'b0;
        load_count <= 5'd0;
        sort_pass <= 5'd0;
        sort_index <= 5'd0;
        sort_swapped <= 1'b0;
        sched_index <= 5'd0;
        for (i = 0; i < T; i = i + 1) begin
            tech_free_time[i] <= 32'd0;
        end
        min_free_time <= 32'd0;
        min_tech <= 2'd0;
        completion_time <= 32'd0;
        delay <= 32'd0;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: if (load_done) next_state = SORT;
        SORT: if (sort_pass >= load_count - 1 || !sort_swapped) next_state = SCHEDULE;
        SCHEDULE: if (sched_index >= load_count) next_state = DONE;
        DONE: next_state = DONE;
        default: next_state = IDLE;
    endcase
end

// Load logic
always @(posedge clk) begin
    if (state == LOAD && load_enable && load_count < N) begin
        drop_time[load_count] <= load_drop_time;
        type_reg[load_count] <= load_type;
        fill_time[load_count] <= load_fill_time;
        load_count <= load_count + 1;
    end else if (state == IDLE) begin
        load_count <= 5'd0;
    end
end

// Bubble sort
always @(posedge clk) begin
    if (state == SORT) begin
        if (sort_index >= load_count - 1 - sort_pass) begin
            // End of pass
            if (!sort_swapped) begin
                sort_pass <= load_count;  // Done if no swaps
            end else begin
                sort_pass <= sort_pass + 1;
                sort_index <= 5'd0;
                sort_swapped <= 1'b0;
            end
        end else begin
            // Compare and swap if needed
            if (should_swap(sort_index, sort_index + 1)) begin
                // Swap
                drop_time[sort_index] <= drop_time[sort_index + 1];
                type_reg[sort_index] <= type_reg[sort_index + 1];
                fill_time[sort_index] <= fill_time[sort_index + 1];
                drop_time[sort_index + 1] <= drop_time[sort_index];
                type_reg[sort_index + 1] <= type_reg[sort_index];
                fill_time[sort_index + 1] <= fill_time[sort_index];
                sort_swapped <= 1'b1;
            end
            sort_index <= sort_index + 1;
        end
    end else begin
        sort_pass <= 5'd0;
        sort_index <= 5'd0;
        sort_swapped <= 1'b0;
    end
end

// Compare function for sorting
function should_swap;
    input [4:0] i, j;
    begin
        should_swap = 1'b0;
        // Compare drop_time
        if (drop_time[i] > drop_time[j]) begin
            should_swap = 1'b1;
        end else if (drop_time[i] == drop_time[j]) begin
            // Compare type (S first, then R)
            if (type_reg[i] < type_reg[j]) begin
                should_swap = 1'b1;  // S=1, R=0, so 0<1 means R<S -> swap
            end else if (type_reg[i] == type_reg[j]) begin
                // Compare fill_time (shorter first)
                if (fill_time[i] > fill_time[j]) begin
                    should_swap = 1'b1;
                end
            end
        end
    end
endfunction

// Find minimum free time and technician
always @(*) begin
    min_free_time = tech_free_time[0];
    min_tech = 2'd0;
    for (i = 1; i < T; i = i + 1) begin
        if (tech_free_time[i] < min_free_time) begin
            min_free_time = tech_free_time[i];
            min_tech = i;
        end
    end
end

// Scheduling logic
always @(posedge clk) begin
    if (state == SCHEDULE) begin
        if (sched_index < load_count) begin
            // Compute completion time
            if (drop_time[sched_index] > min_free_time) begin
                completion_time <= drop_time[sched_index] + fill_time[sched_index];
                delay <= fill_time[sched_index];
            end else begin
                completion_time <= min_free_time + fill_time[sched_index];
                delay <= min_free_time - drop_time[sched_index] + fill_time[sched_index];
            end
            
            // Update sums and counts
            if (type_reg[sched_index] == 1'b1) begin  // S
                sum_S <= sum_S + delay;
                count_S <= count_S + 1;
            end else begin  // R
                sum_R <= sum_R + delay;
                count_R <= count_R + 1;
            end
            
            // Update technician free time
            tech_free_time[min_tech] <= completion_time;
            
            sched_index <= sched_index + 1;
        end
    end else if (state != SCHEDULE) begin
        sched_index <= 5'd0;
    end
end

// Done signal
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
    end else if (state == DONE) begin
        done <= 1'b1;
    end else begin
        done <= 1'b0;
    end
end

endmodule