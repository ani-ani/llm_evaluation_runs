module break_scheduler (
    input clk,
    input rst_n,
    input start,
    input [4:0] concert_length, // T (0-31)
    input [2:0] num_musicians, // N (0-7)
    input [7:0][4:0] break_durations, // durations for up to 8 musicians (0-31)
    output reg [4:0] start_times [0:7], // start time for each musician
    output reg done,
    output reg valid // high if scheduling successful
);

// State machine
reg [2:0] state;
localparam IDLE = 3'd0;
localparam SCHEDULE = 3'd1;
localparam CHECK_SLOT = 3'd2;
localparam UPDATE = 3'd3;
localparam COMPLETE = 3'd4;

// Timeline occupancy tracking: each bit represents 1 minute slot
reg [31:0] occupancy;

// Internal counters and registers
reg [2:0] musician_idx; // Current musician being scheduled
reg [4:0] time_cursor; // Current time being checked
reg [4:0] current_duration; // Duration of current musician

// Registers for slot checking
reg [4:0] check_start;
reg [4:0] check_end;
reg [4:0] overlap_count;
reg slot_valid;

// Helper: count overlaps in a range
function [4:0] count_overlaps;
    input [4:0] start;
    input [4:0] duration;
    reg [31:0] mask;
    reg [31:0] masked;
    integer i;
    begin
        mask = 0;
        for (i = 0; i < 32; i = i + 1) begin
            if (i >= start && i < (start + duration)) begin
                mask[i] = 1;
            end
        end
        masked = occupancy & mask;
        count_overlaps = 0;
        for (i = 0; i < 32; i = i + 1) begin
            if (masked[i]) count_overlaps = count_overlaps + 1;
        end
    end
endfunction

// Helper: create mask for a range
function [31:0] create_mask;
    input [4:0] start;
    input [4:0] duration;
    integer i;
    begin
        create_mask = 0;
        for (i = 0; i < 32; i = i + 1) begin
            if (i >= start && i < (start + duration)) begin
                create_mask[i] = 1;
            end
        end
    end
endfunction

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        valid <= 0;
        occupancy <= 0;
        musician_idx <= 0;
        time_cursor <= 0;
        current_duration <= 0;
        // Initialize start_times to 0
        start_times[0] <= 0;
        start_times[1] <= 0;
        start_times[2] <= 0;
        start_times[3] <= 0;
        start_times[4] <= 0;
        start_times[5] <= 0;
        start_times[6] <= 0;
        start_times[7] <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= SCHEDULE;
                    occupancy <= 0;
                    musician_idx <= 0;
                    done <= 0;
                    valid <= 0;
                    time_cursor <= 0;
                end
            end
            
            SCHEDULE: begin
                if (musician_idx < num_musicians) begin
                    current_duration <= break_durations[musician_idx];
                    time_cursor <= 0;
                    state <= CHECK_SLOT;
                end else begin
                    // All musicians scheduled successfully
                    done <= 1;
                    valid <= 1;
                    state <= IDLE;
                end
            end
            
            CHECK_SLOT: begin
                // Check if current time cursor is valid
                if ((time_cursor + current_duration) <= concert_length) begin
                    // Check overlap count
                    overlap_count <= count_overlaps(time_cursor, current_duration);
                    state <= UPDATE;
                end else begin
                    // No valid slot found - scheduling failed
                    done <= 1;
                    valid <= 0;
                    state <= IDLE;
                end
            end
            
            UPDATE: begin
                if (overlap_count <= 2) begin
                    // Found valid slot
                    start_times[musician_idx] <= time_cursor;
                    occupancy <= occupancy | create_mask(time_cursor, current_duration);
                    musician_idx <= musician_idx + 1;
                    state <= SCHEDULE;
                end else begin
                    // Slot too crowded, try next time
                    time_cursor <= time_cursor + 1;
                    state <= CHECK_SLOT;
                end
            end
            
            COMPLETE: begin
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule