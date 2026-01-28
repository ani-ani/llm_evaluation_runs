module VolcanoPath(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] m_count,
    input wire [15:0] volcano_x [0:63],
    input wire [15:0] volcano_y [0:63],
    output reg [31:0] result,
    output reg done
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_START_END = 3'd1;
    localparam [2:0] SORT_VOLCANOES = 3'd2;
    localparam [2:0] PROCESS_ROWS = 3'd3;
    localparam [2:0] COMPUTE_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Constants
    localparam [15:0] MAX_VOLCANOES = 16'd64;
    localparam [15:0] MAX_ROWS = 16'd16;
    localparam [15:0] MAX_INTERVALS = 16'd8;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [15:0] current_row;
    reg [15:0] volcano_index;
    reg [15:0] interval_count;
    reg [15:0] sorted_volcanoes [0:63];
    reg [15:0] sorted_x [0:63];
    reg [15:0] sorted_y [0:63];
    reg [15:0] intervals_start [0:7];
    reg [15:0] intervals_end [0:7];
    reg [15:0] temp_x, temp_y;
    reg [15:0] i, j, k;
    reg [15:0] n;
    reg start_blocked, end_blocked;
    reg [15:0] min_x, min_y;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_row <= 16'd0;
            volcano_index <= 16'd0;
            interval_count <= 16'd0;
            start_blocked <= 1'b0;
            end_blocked <= 1'b0;
            min_x <= 16'd0;
            min_y <= 16'd0;
            result <= 32'd0;
            done <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 64; i = i + 1) begin
                sorted_volcanoes[i] <= 16'd0;
                sorted_x[i] <= 16'd0;
                sorted_y[i] <= 16'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                intervals_start[i] <= 16'd0;
                intervals_end[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_START_END;
                    cycle_count = 8'd0;
                    n = 16'd16; // Fixed grid size
                    start_blocked = 1'b0;
                    end_blocked = 1'b0;
                end
            end

            CHECK_START_END: begin
                // Check if start (1,1) or end (n,n) has volcano
                for (i = 0; i < m_count && i < MAX_VOLCANOES; i = i + 1) begin
                    if (volcano_x[i] == 16'd1 && volcano_y[i] == 16'd1) begin
                        start_blocked = 1'b1;
                    end
                    if (volcano_x[i] == n && volcano_y[i] == n) begin
                        end_blocked = 1'b1;
                    end
                end
                
                if (start_blocked || end_blocked) begin
                    next_state = COMPUTE_RESULT;
                end else if (m_count == 16'd0) begin
                    next_state = COMPUTE_RESULT;
                end else begin
                    next_state = SORT_VOLCANOES;
                end
            end

            SORT_VOLCANOES: begin
                // Simple bubble sort for volcanoes by y (row)
                for (i = 0; i < m_count - 16'd1 && i < MAX_VOLCANOES - 16'd1; i = i + 1) begin
                    for (j = 0; j < m_count - i - 16'd1 && j < MAX_VOLCANOES - i - 16'd1; j = j + 1) begin
                        if (volcano_y[j] > volcano_y[j + 16'd1]) begin
                            // Swap
                            temp_x = volcano_x[j];
                            temp_y = volcano_y[j];
                            volcano_x[j] = volcano_x[j + 16'd1];
                            volcano_y[j] = volcano_y[j + 16'd1];
                            volcano_x[j + 16'd1] = temp_x;
                            volcano_y[j + 16'd1] = temp_y;
                        end
                    end
                end
                
                // Copy sorted data
                for (i = 0; i < m_count && i < MAX_VOLCANOES; i = i + 1) begin
                    sorted_x[i] = volcano_x[i];
                    sorted_y[i] = volcano_y[i];
                end
                
                next_state = PROCESS_ROWS;
                current_row = 16'd1;
                volcano_index = 16'd0;
                interval_count = 16'd1;
                intervals_start[0] = 16'd1;
                intervals_end[0] = n;
            end

            PROCESS_ROWS: begin
                // Process current row
                if (current_row > n) begin
                    next_state = COMPUTE_RESULT;
                end else begin
                    // Process volcanoes in current row
                    if (volcano_index < m_count && volcano_index < MAX_VOLCANOES && 
                        sorted_y[volcano_index] == current_row) begin
                        temp_x = sorted_x[volcano_index];
                        
                        // Remove intervals that contain this volcano
                        for (i = 0; i < interval_count; i = i + 1) begin
                            if (intervals_start[i] <= temp_x && temp_x <= intervals_end[i]) begin
                                // Split interval
                                if (temp_x > intervals_start[i]) begin
                                    intervals_end[i] = temp_x - 16'd1;
                                end else if (temp_x < intervals_end[i]) begin
                                    intervals_start[i] = temp_x + 16'd1;
                                end else begin
                                    // Remove this interval
                                    for (j = i; j < interval_count - 16'd1; j = j + 1) begin
                                        intervals_start[j] = intervals_start[j + 16'd1];
                                        intervals_end[j] = intervals_end[j + 16'd1];
                                    end
                                    interval_count = interval_count - 16'd1;
                                    i = i - 16'd1; // Adjust index after removal
                                end
                            end
                        end
                        
                        volcano_index = volcano_index + 16'd1;
                    end else begin
                        // Move to next row
                        if (interval_count == 16'd0) begin
                            // No path available
                            next_state = COMPUTE_RESULT;
                        end else begin
                            // Extend intervals to next row
                            current_row = current_row + 16'd1;
                        end
                    end
                end
            end

            COMPUTE_RESULT: begin
                if (start_blocked || end_blocked || interval_count == 16'd0) begin
                    result = 32'd4294967295; // -1 in 32-bit two's complement
                end else begin
                    result = 32'd30; // 2*(16-1) = 30
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Done signal generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Cycle counter for timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            if (cycle_count < MAX_CYCLES - 8'd1) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                // Timeout - force to done state
                cycle_count <= 8'd0;
                if (state != DONE_STATE) begin
                    next_state = DONE_STATE;
                    result <= 32'd4294967295; // -1 on timeout
                end
            end
        end
    end

endmodule