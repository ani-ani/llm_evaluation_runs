module concert_scheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] t_in,
    input wire [9:0] n_in,
    input wire [15:0] b_in,
    input wire b_valid,
    output reg [15:0] s_out,
    output reg s_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] SCHEDULE  = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Counters and storage
    reg [9:0] musician_count;
    reg [15:0] time_counter;
    reg [15:0] current_b;
    reg [15:0] current_s;

    // Storage arrays for scheduled breaks (max 500 musicians)
    reg [15:0] start_times [0:499];
    reg [15:0] end_times [0:499];
    reg [9:0] valid_entries;

    // Active break counter (2-bit since max overlap is 2)
    reg [1:0] active_count;
    reg [9:0] check_index;

    // Control flags
    reg found_slot;
    reg [9:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            musician_count <= 10'd0;
            time_counter <= 16'd0;
            current_b <= 16'd0;
            current_s <= 16'd0;
            valid_entries <= 10'd0;
            s_out <= 16'd0;
            s_valid <= 1'b0;
            done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 500; i = i + 1) begin
                start_times[i] <= 16'd0;
                end_times[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        s_valid = 1'b0;
        done = 1'b0;
        found_slot = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    musician_count = 10'd0;
                    valid_entries = 10'd0;
                end
            end

            LOAD: begin
                if (b_valid) begin
                    current_b = b_in;
                    musician_count = musician_count + 10'd1;
                    time_counter = 16'd0;
                    next_state = SCHEDULE;
                end
            end

            SCHEDULE: begin
                // Check if we've found a slot or reached the end
                if (found_slot || time_counter >= t_in - current_b) begin
                    if (found_slot) begin
                        start_times[valid_entries] = current_s;
                        end_times[valid_entries] = current_s + current_b;
                        valid_entries = valid_entries + 10'd1;
                        s_out = current_s;
                        s_valid = 1'b1;
                    end
                    next_state = OUTPUT;
                end else begin
                    // Check if current time slot is valid
                    active_count = 2'd0;
                    for (check_index = 0; check_index < valid_entries; check_index = check_index + 1) begin
                        if (start_times[check_index] <= time_counter && 
                            end_times[check_index] > time_counter) begin
                            active_count = active_count + 2'd1;
                        end
                    end

                    // If less than 2 overlaps, schedule here
                    if (active_count < 2'd2) begin
                        current_s = time_counter;
                        found_slot = 1'b1;
                    end else begin
                        time_counter = time_counter + 16'd1;
                    end
                end
            end

            OUTPUT: begin
                if (musician_count >= n_in) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = LOAD;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule