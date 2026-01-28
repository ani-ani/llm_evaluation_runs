module MaximumPrioritySubset (
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_STREAMS = 3'd1;
    localparam [2:0] PROCESS_DP = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] WAIT = 3'd4;

    // DP memory and stream buffer
    reg [15:0] dp_mem [0:255];
    reg [7:0] stream_buf_start [0:7];
    reg [7:0] stream_buf_end [0:7];
    reg [15:0] stream_buf_prio [0:7];
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] stream_count;
    reg [7:0] time_idx;
    reg [7:0] stream_idx;
    reg [15:0] temp_result;
    reg [15:0] candidate;
    reg [7:0] load_counter;
    reg [7:0] proc_time;
    reg done_pulse;
    integer i;

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            busy <= 1'b0;
            stream_count <= 8'd0;
            time_idx <= 8'd0;
            stream_idx <= 8'd0;
            temp_result <= 16'd0;
            candidate <= 16'd0;
            load_counter <= 8'd0;
            proc_time <= 8'd0;
            done_pulse <= 1'b0;
            // Initialize DP memory
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
            
            // Clear done pulse after one cycle
            if (done_pulse) begin
                done <= 1'b1;
                done_pulse <= 1'b0;
            end else begin
                done <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    stream_count <= 8'd0;
                    load_counter <= 8'd0;
                    if (start) begin
                        busy <= 1'b1;
                    end
                end
                
                LOAD_STREAMS: begin
                    if (stream_valid && load_counter < 8'd8) begin
                        stream_buf_start[load_counter] <= stream_start;
                        stream_buf_end[load_counter] <= stream_end;
                        stream_buf_prio[load_counter] <= stream_prio;
                        load_counter <= load_counter + 8'd1;
                        stream_count <= stream_count + 8'd1;
                    end
                    time_idx <= 8'd0;
                    proc_time <= 8'd0;
                end
                
                PROCESS_DP: begin
                    proc_time <= proc_time + 8'd1;
                    
                    if (proc_time < 8'd255) begin
                        time_idx <= time_idx + 8'd1;
                        
                        // Default: carry over previous dp value
                        if (time_idx < 8'd255) begin
                            dp_mem[time_idx + 8'd1] <= dp_mem[time_idx];
                        end
                        
                        // Check all streams in buffer
                        for (stream_idx = 0; stream_idx < 8; stream_idx = stream_idx + 1) begin
                            if (stream_idx < stream_count) begin
                                if (stream_buf_end[stream_idx] == (time_idx + 8'd1)) begin
                                    // Calculate candidate = dp[start] + priority
                                    if (stream_buf_start[stream_idx] == 8'd0) begin
                                        candidate <= stream_buf_prio[stream_idx];
                                    end else if (stream_buf_start[stream_idx] <= 8'd255) begin
                                        candidate <= dp_mem[stream_buf_start[stream_idx]] + stream_buf_prio[stream_idx];
                                    end
                                    
                                    // Update dp if candidate is larger
                                    if (stream_buf_start[stream_idx] == 8'd0) begin
                                        if (stream_buf_prio[stream_idx] > dp_mem[time_idx + 8'd1]) begin
                                            dp_mem[time_idx + 8'd1] <= stream_buf_prio[stream_idx];
                                        end
                                    end else if (stream_buf_start[stream_idx] <= 8'd255) begin
                                        if ((dp_mem[stream_buf_start[stream_idx]] + stream_buf_prio[stream_idx]) > dp_mem[time_idx + 8'd1]) begin
                                            dp_mem[time_idx + 8'd1] <= dp_mem[stream_buf_start[stream_idx]] + stream_buf_prio[stream_idx];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                OUTPUT: begin
                    result <= dp_mem[8'd255];
                    done_pulse <= 1'b1;
                end
                
                WAIT: begin
                    // Wait state
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_STREAMS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD_STREAMS: begin
                if (!stream_valid && load_counter > 8'd0) begin
                    next_state = PROCESS_DP;
                end else if (load_counter >= 8'd8) begin
                    next_state = PROCESS_DP;
                end else begin
                    next_state = LOAD_STREAMS;
                end
            end
            
            PROCESS_DP: begin
                if (proc_time >= 8'd255) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = PROCESS_DP;
                end
            end
            
            OUTPUT: begin
                next_state = WAIT;
            end
            
            WAIT: begin
                if (!busy) begin
                    next_state = IDLE;
                end else begin
                    next_state = WAIT;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule