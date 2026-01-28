module MaxPrioritySubsetSelector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire stream_valid,
    input wire [7:0] stream_start,
    input wire [7:0] stream_end,
    input wire [15:0] stream_prio,
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_STREAMS = 2'd1;
    localparam [1:0] PROCESS_DP = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;
    
    reg [1:0] state, next_state;
    
    // DP memory (256 entries, 16-bit each)
    reg [15:0] dp_mem [0:255];
    
    // Stream buffer (8 streams max)
    reg [7:0] stream_buf_start [0:7];
    reg [7:0] stream_buf_end [0:7];
    reg [15:0] stream_buf_prio [0:7];
    reg [2:0] stream_count;
    reg [2:0] current_stream_idx;
    
    // Processing counters
    reg [7:0] time_counter;
    reg [2:0] stream_process_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            stream_count <= 3'd0;
            current_stream_idx <= 3'd0;
            time_counter <= 8'd0;
            stream_process_idx <= 3'd0;
            cycle_count <= 8'd0;
            
            // Initialize DP memory
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                dp_mem[i] <= 16'd0;
            end
            
            // Initialize stream buffer
            for (i = 0; i < 8; i = i + 1) begin
                stream_buf_start[i] <= 8'd0;
                stream_buf_end[i] <= 8'd0;
                stream_buf_prio[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_STREAMS;
                end
            end
            
            LOAD_STREAMS: begin
                if (stream_count == 3'd7 || !stream_valid) begin
                    next_state = PROCESS_DP;
                end
            end
            
            PROCESS_DP: begin
                if (time_counter == 8'd255 && stream_process_idx == 3'd7) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Stream loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else begin
            if (state == LOAD_STREAMS && stream_valid) begin
                stream_buf_start[stream_count] <= stream_start;
                stream_buf_end[stream_count] <= stream_end;
                stream_buf_prio[stream_count] <= stream_prio;
                stream_count <= stream_count + 3'd1;
            end
        end
    end
    
    // DP processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else begin
            if (state == PROCESS_DP) begin
                // Initialize processing
                if (time_counter == 8'd0 && stream_process_idx == 3'd0) begin
                    dp_mem[0] <= 16'd0;
                    time_counter <= 8'd1;
                end
                // Process each time slot
                else if (time_counter < 8'd256) begin
                    // Carry forward previous value
                    dp_mem[time_counter] <= dp_mem[time_counter - 1'b1];
                    
                    // Check all streams ending at current time
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (stream_buf_end[i] == time_counter) begin
                            reg [15:0] candidate;
                            candidate = dp_mem[stream_buf_start[i]] + stream_buf_prio[i];
                            
                            if (candidate > dp_mem[time_counter]) begin
                                dp_mem[time_counter] <= candidate;
                            end
                        end
                    end
                    
                    time_counter <= time_counter + 8'd1;
                end
                // Move to next stream if needed
                else if (stream_process_idx < 3'd7) begin
                    time_counter <= 8'd0;
                    stream_process_idx <= stream_process_idx + 3'd1;
                end
            end
        end
    end
    
    // Output handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset
        end else begin
            if (state == OUTPUT) begin
                result <= dp_mem[8'd255];
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    // Busy signal
    always @(*) begin
        busy = (state != IDLE);
    end
    
    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                
                // Safety: Force return to IDLE if max cycles exceeded
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end else begin
                cycle_count <= 8'd0;
            end
        end
    end
endmodule