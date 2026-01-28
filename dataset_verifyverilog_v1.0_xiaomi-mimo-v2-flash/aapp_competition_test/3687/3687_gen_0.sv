module interplanetary_fifo_system (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] sensor_queue_map [0:7],
    input wire [7:0] queue_capacity [0:7],
    input wire [15:0] downlink_bandwidth [0:15],
    input wire [15:0] sensor_data [0:15],
    output reg result,
    output reg done,
    output reg [1:0] status
);

    // State definitions
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] OVERFLOW    = 2'd2;
    localparam [1:0] SUCCESS     = 2'd3;

    // State and control registers
    reg [1:0] state, next_state;
    reg [3:0] window_idx, next_window_idx;  // 0-15 for 16 windows
    reg [3:0] sensor_idx, next_sensor_idx;  // 0-7 for 8 sensors
    reg [3:0] queue_idx, next_queue_idx;    // 0-7 for 8 queues
    reg [7:0] cycle_count, next_cycle_count;
    
    // Queue fill levels (16-bit each, 8 queues)
    reg [15:0] queue_fill [0:7];
    reg [15:0] next_queue_fill [0:7];
    
    // Transfer bandwidth tracking
    reg [15:0] remaining_bw;
    reg [15:0] next_remaining_bw;
    
    // Intermediate signals for operations
    reg [15:0] add_result;
    reg [15:0] transfer_amount;
    reg overflow_detected;
    reg transfer_done;
    
    // Max cycles constraint (256 cycles)
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // Constant queue capacity (scaled from 10^6 to 8192)
    localparam [15:0] FIXED_QUEUE_CAPACITY = 16'd8192;
    
    // Integer for loops
    integer i;

    // State transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            window_idx <= 4'd0;
            sensor_idx <= 4'd0;
            queue_idx <= 4'd0;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            status <= IDLE;
            remaining_bw <= 16'd0;
            // Initialize all queue fill levels
            for (i = 0; i < 8; i = i + 1) begin
                queue_fill[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            window_idx <= next_window_idx;
            sensor_idx <= next_sensor_idx;
            queue_idx <= next_queue_idx;
            cycle_count <= next_cycle_count;
            remaining_bw <= next_remaining_bw;
            // Update queue fills
            for (i = 0; i < 8; i = i + 1) begin
                queue_fill[i] <= next_queue_fill[i];
            end
            // Update outputs
            status <= next_state;  // status reflects current state
        end
    end

    // Main FSM logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_window_idx = window_idx;
        next_sensor_idx = sensor_idx;
        next_queue_idx = queue_idx;
        next_cycle_count = cycle_count + 8'd1;
        next_remaining_bw = remaining_bw;
        result = result;
        done = 1'b0;
        
        // Initialize next queue fills to current values
        for (i = 0; i < 8; i = i + 1) begin
            next_queue_fill[i] = queue_fill[i];
        end
        
        // Operation signals
        overflow_detected = 1'b0;
        transfer_done = 1'b0;
        
        case (state)
            IDLE: begin
                next_cycle_count = 8'd0;
                next_window_idx = 4'd0;
                next_sensor_idx = 4'd0;
                next_queue_idx = 4'd0;
                next_remaining_bw = 16'd0;
                result = 1'b0;
                done = 1'b0;
                
                // Initialize all queues to zero
                for (i = 0; i < 8; i = i + 1) begin
                    next_queue_fill[i] = 16'd0;
                end
                
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                if (cycle_count >= MAX_CYCLES) begin
                    // Timeout protection
                    next_state = OVERFLOW;
                    result = 1'b0;
                    done = 1'b1;
                end else if (window_idx < 16) begin
                    // Still processing windows
                    
                    if (sensor_idx < 8) begin
                        // Add sensor data to queue
                        // Check if this sensor is valid (sensor_idx < s)
                        // In this implementation, we process all 8 sensors
                        // but actual sensors would be limited by s
                        
                        // Get target queue index
                        reg [3:0] target_queue;
                        target_queue = sensor_queue_map[sensor_idx];
                        
                        // Get sensor data value
                        reg [15:0] data_amount;
                        data_amount = sensor_data[sensor_idx];
                        
                        // Calculate new fill level
                        reg [16:0] new_fill;  // 17-bit for overflow detection
                        new_fill = queue_fill[target_queue] + data_amount;
                        
                        // Check for overflow (exceeds capacity or wraps around)
                        if (new_fill > FIXED_QUEUE_CAPACITY || new_fill[16]) begin
                            next_state = OVERFLOW;
                            result = 1'b0;
                            done = 1'b1;
                        end else begin
                            // Update queue fill
                            next_queue_fill[target_queue] = new_fill[15:0];
                            next_sensor_idx = sensor_idx + 4'd1;
                            next_state = PROCESSING;
                        end
                    end else if (queue_idx == 4'd8) begin
                        // All sensors processed for this window, now transfer data
                        // Initialize transfer
                        next_remaining_bw = downlink_bandwidth[window_idx];
                        next_queue_idx = 4'd0;
                        next_sensor_idx = 4'd0;  // Reuse as transfer counter
                        // Stay in PROCESSING state
                    end else if (queue_idx < 4'd8) begin
                        // Transfer data from queue (high index first)
                        // Queue indices are 0-7, process from 7 down to 0
                        reg [3:0] current_q;
                        current_q = 4'd7 - queue_idx;
                        
                        reg [15:0] queue_level;
                        queue_level = queue_fill[current_q];
                        
                        reg [15:0] transfer_amt;
                        if (remaining_bw >= queue_level) begin
                            transfer_amt = queue_level;
                            next_queue_fill[current_q] = 16'd0;
                            next_remaining_bw = remaining_bw - queue_level;
                        end else begin
                            transfer_amt = remaining_bw;
                            next_queue_fill[current_q] = queue_level - remaining_bw;
                            next_remaining_bw = 16'd0;
                        end
                        
                        next_queue_idx = queue_idx + 4'd1;
                        next_state = PROCESSING;
                    end else begin
                        // Window processing complete, move to next window
                        // Check if this was the last window
                        if (window_idx == 4'd15) begin
                            // All windows processed, validate queues
                            reg queues_empty;
                            queues_empty = 1'b1;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (queue_fill[i] != 16'd0) begin
                                    queues_empty = 1'b0;
                                end
                            end
                            
                            if (queues_empty) begin
                                next_state = SUCCESS;
                                result = 1'b1;
                                done = 1'b1;
                            end else begin
                                next_state = OVERFLOW;
                                result = 1'b0;
                                done = 1'b1;
                            end
                        end else begin
                            // Move to next window
                            next_window_idx = window_idx + 4'd1;
                            next_sensor_idx = 4'd0;
                            next_queue_idx = 4'd0;
                            next_remaining_bw = 16'd0;
                            next_state = PROCESSING;
                        end
                    end
                end else begin
                    // Should not reach here, but safety net
                    next_state = OVERFLOW;
                    result = 1'b0;
                    done = 1'b1;
                end
            end
            
            OVERFLOW: begin
                // Error state
                result = 1'b0;
                done = 1'b0;  // Done already pulsed
                next_cycle_count = cycle_count;  // Stop counting
                // Stay in overflow state
            end
            
            SUCCESS: begin
                // Success state
                result = 1'b1;
                done = 1'b0;  // Done already pulsed
                next_cycle_count = cycle_count;  // Stop counting
                // Stay in success state
            end
            
            default: begin
                next_state = IDLE;
                next_window_idx = 4'd0;
                next_sensor_idx = 4'd0;
                next_queue_idx = 4'd0;
                next_cycle_count = 8'd0;
                result = 1'b0;
                done = 1'b0;
            end
        endcase
    end

endmodule