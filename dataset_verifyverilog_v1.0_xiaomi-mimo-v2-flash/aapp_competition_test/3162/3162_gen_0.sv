module LCD_Pixel_Activator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire pulse_direction,
    input wire [15:0] pulse_time,
    input wire [15:0] pulse_length,
    input wire [4:0] pulse_wire,
    input wire valid_i,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_PULSES  = 3'd1;
    localparam [2:0] CALCULATE    = 3'd2;
    localparam [2:0] DONE         = 3'd3;

    // Memory arrays (16 entries each)
    reg [15:0] h_time_reg [0:15];
    reg [15:0] h_len_reg [0:15];
    reg h_valid_reg [0:15];
    
    reg [15:0] v_time_reg [0:15];
    reg [15:0] v_len_reg [0:15];
    reg v_valid_reg [0:15];

    // FSM registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [4:0] load_idx;          // Tracks pulse storage location
    reg [4:0] h_idx;             // Horizontal pulse index
    reg [4:0] v_idx;             // Vertical pulse index
    reg [31:0] result_count;
    reg [31:0] cycle_count;      // Prevent infinite loops
    localparam [31:0] MAX_CYCLES = 32'd1000;

    // Timing calculation wires
    wire [15:0] v_start_time;
    wire [15:0] v_end_time;
    wire [15:0] h_start_time;
    wire [15:0] h_end_time;
    wire [15:0] overlap_start;
    wire [15:0] overlap_end;
    wire overlap_exists;

    // Calculate timing for current pulse pair
    assign v_start_time = v_time_reg[v_idx] + (v_idx[4:0] - 5'd1);
    assign v_end_time = v_start_time + v_len_reg[v_idx];
    assign h_start_time = h_time_reg[h_idx] + (h_idx[4:0] - 5'd1);
    assign h_end_time = h_start_time + h_len_reg[h_idx];

    // Overlap detection: max(start_v, start_h) < min(end_v, end_h)
    assign overlap_start = (v_start_time > h_start_time) ? v_start_time : h_start_time;
    assign overlap_end = (v_end_time < h_end_time) ? v_end_time : h_end_time;
    assign overlap_exists = (overlap_start < overlap_end);

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            load_idx <= 5'd0;
            h_idx <= 5'd0;
            v_idx <= 5'd0;
            result_count <= 32'd0;
            cycle_count <= 32'd0;
            // Initialize all memory entries
            begin : init_mem
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    h_time_reg[i] <= 16'd0;
                    h_len_reg[i] <= 16'd0;
                    h_valid_reg[i] <= 1'b0;
                    v_time_reg[i] <= 16'd0;
                    v_len_reg[i] <= 16'd0;
                    v_valid_reg[i] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;
            done <= 1'b0; // done is single cycle
            cycle_count <= cycle_count + 32'd1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    load_idx <= 5'd0;
                    result_count <= 32'd0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        // Clear previous data on new start
                        begin : clear_mem
                            integer i;
                            for (i = 0; i < 16; i = i + 1) begin
                                h_valid_reg[i] <= 1'b0;
                                v_valid_reg[i] <= 1'b0;
                            end
                        end
                        busy <= 1'b1;
                        next_state <= LOAD_PULSES;
                    end
                end

                LOAD_PULSES: begin
                    if (valid_i && load_idx < 5'd16) begin
                        if (pulse_direction == 1'b0) begin // Horizontal
                            h_time_reg[load_idx] <= pulse_time;
                            h_len_reg[load_idx] <= pulse_length;
                            h_valid_reg[load_idx] <= 1'b1;
                        end else begin // Vertical
                            v_time_reg[load_idx] <= pulse_time;
                            v_len_reg[load_idx] <= pulse_length;
                            v_valid_reg[load_idx] <= 1'b1;
                        end
                        load_idx <= load_idx + 5'd1;
                    end
                    // Transition to calculation when start goes low or buffer full
                    if (!start) begin
                        next_state <= CALCULATE;
                        h_idx <= 5'd0;
                        v_idx <= 5'd0;
                    end
                end

                CALCULATE: begin
                    // Iterate through all horizontal pulses
                    if (h_idx < 5'd16) begin
                        // Only check valid horizontal pulses
                        if (h_valid_reg[h_idx]) begin
                            // Iterate through all vertical pulses
                            if (v_idx < 5'd16) begin
                                if (v_valid_reg[v_idx] && overlap_exists) begin
                                    result_count <= result_count + 32'd1;
                                end
                                v_idx <= v_idx + 5'd1;
                            end else begin
                                // Reset vertical index for next horizontal pulse
                                v_idx <= 5'd0;
                                h_idx <= h_idx + 5'd1;
                            end
                        end else begin
                            // Skip invalid horizontal pulse
                            h_idx <= h_idx + 5'd1;
                            v_idx <= 5'd0;
                        end
                        // Timeout check
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state <= DONE;
                        end
                    end else begin
                        // All pairs processed
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    result <= result_count;
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule