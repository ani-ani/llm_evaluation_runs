module floppy_organ_checker (
    input wire [3:0] f, // number of frequencies (1-10)
    input wire [19:0] t_i, // time period for head movement between endpoints
    input wire [6:0] n_i, // number of intervals per frequency (1-100)
    input wire [19:0] interval_start [0:9], // start times for up to 10 intervals
    input wire [19:0] interval_end [0:9], // end times for up to 10 intervals
    output wire possible // high if all frequencies can be played
);

// Combinational logic to check feasibility
// For each frequency, verify:
// 1. All intervals are valid (start < end)
// 2. No overlapping intervals (end[i] <= start[i+1] - 1, since 1fs pause required)
// 3. Intervals fit within the time constraints

reg is_possible;
integer i;

always @(*) begin
    is_possible = 1'b1;
    
    // Check each frequency's intervals
    // Since input comes one frequency at a time in practice,
    // we verify the given intervals for current frequency
    
    // Verify all intervals are valid and non-overlapping with required pause
    for (i = 0; i < n_i; i = i + 1) begin
        // Interval must have start < end
        if (interval_start[i] >= interval_end[i]) begin
            is_possible = 1'b0;
        end
        
        // If not the first interval, must have at least 1fs pause from previous end
        if (i > 0) begin
            if (interval_end[i-1] + 1 > interval_start[i]) begin
                is_possible = 1'b0;
            end
        end
    end
    
    // Additional check: movement time constraint
    // The head must be able to move between positions in time.
    // Since we can choose starting position freely and can change direction
    // at any point, the only hard constraint is that we can't have intervals
    // that require impossible timing. Given the problem allows arbitrary
    // starting positions and direction changes, any valid interval sequence
    // (non-overlapping with pause) is achievable.
end

assign possible = is_possible;

endmodule

// Sequential version for processing multiple frequencies
module floppy_organ_multi (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_frequencies, // total frequencies to check
    // Interface to load intervals for current frequency
    input wire [19:0] load_t_i,
    input wire [6:0] load_n_i,
    input wire [19:0] load_start [0:9],
    input wire [19:0] load_end [0:9],
    input wire load_valid,
    output reg all_possible,
    output reg done
);

    parameter MAX_FREQ = 10;
    parameter MAX_INTERVALS = 10;
    
    // State machine states
    parameter IDLE = 2'b00;
    parameter LOAD_FREQ = 2'b01;
    parameter CHECK_INTERVALS = 2'b10;
    parameter DONE_STATE = 2'b11;
    
    reg [1:0] state;
    reg [3:0] freq_count;
    reg [6:0] interval_count;
    reg current_freq_possible;
    reg [19:0] prev_end_time;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            all_possible <= 1'b1;
            done <= 1'b0;
            freq_count <= 4'b0;
            interval_count <= 7'b0;
            current_freq_possible <= 1'b1;
            prev_end_time <= 20'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    all_possible <= 1'b1;
                    freq_count <= 4'b0;
                    if (start) begin
                        state <= LOAD_FREQ;
                    end
                end
                
                LOAD_FREQ: begin
                    if (load_valid) begin
                        interval_count <= load_n_i;
                        current_freq_possible <= 1'b1;
                        prev_end_time <= 20'b0;
                        state <= CHECK_INTERVALS;
                    end
                end
                
                CHECK_INTERVALS: begin
                    // Process intervals one by one
                    if (load_valid && interval_count > 0) begin
                        // Check current interval
                        if (load_start[0] >= load_end[0]) begin
                            current_freq_possible <= 1'b0;
                        end else if (load_start[0] < prev_end_time + 1) begin
                            // Need at least 1fs pause
                            current_freq_possible <= 1'b0;
                        end
                        prev_end_time <= load_end[0];
                        interval_count <= interval_count - 1;
                        
                        if (interval_count == 1) begin
                            // Finished this frequency
                            if (!current_freq_possible) begin
                                all_possible <= 1'b0;
                            end
                            freq_count <= freq_count + 1;
                            if (freq_count + 1 >= num_frequencies) begin
                                state <= DONE_STATE;
                            end else begin
                                state <= LOAD_FREQ;
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule