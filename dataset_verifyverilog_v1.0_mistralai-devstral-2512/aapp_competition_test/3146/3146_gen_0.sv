module pharmacy_sim(
    input clk,
    input rst_n,
    input start,
    input presc_valid,
    input [31:0] presc_time,
    input presc_type,
    input [8:0] presc_duration,
    input [3:0] num_technicians,
    output reg busy,
    output reg done,
    output reg [31:0] avg_store,
    output reg [31:0] avg_remote,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Prescription buffer (256 entries)
    reg [31:0] buffer_time [0:255];
    reg buffer_type [0:255];
    reg [8:0] buffer_duration [0:255];
    reg [7:0] buffer_count;
    reg [7:0] buffer_index;

    // Processing variables
    reg [2:0] state;
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2048;

    // Technician tracking
    reg [31:0] tech_available_time [0:9];
    reg [3:0] tech_count;

    // Priority queue (simplified with indices)
    reg [7:0] ready_queue [0:255];
    reg [7:0] queue_size;
    reg [7:0] queue_index;

    // Statistics
    reg [63:0] sum_store;
    reg [63:0] sum_remote;
    reg [7:0] count_store;
    reg [7:0] count_remote;

    // Temporary variables
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] min_index;
    reg [31:0] min_time;
    reg min_type;
    reg [8:0] min_duration;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer_count <= 8'd0;
            buffer_index <= 8'd0;
            busy <= 1'b0;
            done <= 1'b0;
            avg_store <= 32'd0;
            avg_remote <= 32'd0;
            error <= 1'b0;
            cycle_count <= 11'd0;
            queue_size <= 8'd0;
            queue_index <= 8'd0;
            sum_store <= 64'd0;
            sum_remote <= 64'd0;
            count_store <= 8'd0;
            count_remote <= 8'd0;

            // Initialize technician times
            for (i = 0; i < 10; i = i + 1) begin
                tech_available_time[i] <= 32'd0;
            end

            // Initialize buffer
            for (i = 0; i < 256; i = i + 1) begin
                buffer_time[i] <= 32'd0;
                buffer_type[i] <= 1'b0;
                buffer_duration[i] <= 9'd0;
            end

            // Initialize queue
            for (i = 0; i < 256; i = i + 1) begin
                ready_queue[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    error <= (num_technicians == 4'd0);
                    
                    if (presc_valid && buffer_count < 8'd256) begin
                        // Load prescription into buffer
                        buffer_time[buffer_count] <= presc_time;
                        buffer_type[buffer_count] <= presc_type;
                        buffer_duration[buffer_count] <= presc_duration;
                        buffer_count <= buffer_count + 8'd1;
                    end
                    
                    if (start && buffer_count > 8'd0) begin
                        state <= LOAD;
                        busy <= 1'b1;
                        tech_count <= num_technicians;
                        
                        // Initialize statistics
                        sum_store <= 64'd0;
                        sum_remote <= 64'd0;
                        count_store <= 8'd0;
                        count_remote <= 8'd0;
                        
                        // Initialize technician times
                        for (i = 0; i < 10; i = i + 1) begin
                            tech_available_time[i] <= 32'd0;
                        end
                    end
                end

                LOAD: begin
                    // Build initial ready queue (all prescriptions ready at time 0)
                    queue_size <= 8'd0;
                    for (i = 0; i < buffer_count; i = i + 1) begin
                        if (buffer_time[i] == 32'd0) begin
                            ready_queue[queue_size] <= i;
                            queue_size <= queue_size + 8'd1;
                        end
                    end
                    
                    // Sort queue by priority (in-store first, then time, then duration)
                    for (i = 0; i < queue_size - 8'd1; i = i + 1) begin
                        min_index <= i;
                        min_time <= buffer_time[ready_queue[i]];
                        min_type <= buffer_type[ready_queue[i]];
                        min_duration <= buffer_duration[ready_queue[i]];
                        
                        for (j = i + 8'd1; j < queue_size; j = j + 1) begin
                            if (buffer_type[ready_queue[j]] > min_type ||
                                (buffer_type[ready_queue[j]] == min_type && 
                                 (buffer_time[ready_queue[j]] < min_time ||
                                  (buffer_time[ready_queue[j]] == min_time &&
                                   buffer_duration[ready_queue[j]] < min_duration)))) begin
                                min_index <= j;
                                min_time <= buffer_time[ready_queue[j]];
                                min_type <= buffer_type[ready_queue[j]];
                                min_duration <= buffer_duration[ready_queue[j]];
                            end
                        end
                        
                        // Swap
                        if (min_index != i) begin
                            j <= ready_queue[i];
                            ready_queue[i] <= ready_queue[min_index];
                            ready_queue[min_index] <= j;
                        end
                    end
                    
                    state <= PROCESS;
                    cycle_count <= 11'd0;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 11'd1;
                    
                    // Process one event per cycle
                    if (queue_size > 8'd0) begin
                        // Find available technician
                        min_index <= 0;
                        min_time <= tech_available_time[0];
                        
                        for (i = 1; i < tech_count; i = i + 1) begin
                            if (tech_available_time[i] < min_time) begin
                                min_index <= i;
                                min_time <= tech_available_time[i];
                            end
                        end
                        
                        // Assign prescription to technician
                        j <= ready_queue[0];
                        tech_available_time[min_index] <= buffer_time[j] + buffer_duration[j];
                        
                        // Update statistics
                        if (buffer_type[j] == 1'b1) begin
                            sum_store <= sum_store + {{32'd0, buffer_time[j] + buffer_duration[j]}};
                            count_store <= count_store + 8'd1;
                        end else begin
                            sum_remote <= sum_remote + {{32'd0, buffer_time[j] + buffer_duration[j]}};
                            count_remote <= count_remote + 8'd1;
                        end
                        
                        // Remove from queue
                        for (i = 0; i < queue_size - 8'd1; i = i + 1) begin
                            ready_queue[i] <= ready_queue[i + 8'd1];
                        end
                        queue_size <= queue_size - 8'd1;
                        
                        // Add new prescriptions that are now ready
                        for (i = 0; i < buffer_count; i = i + 1) begin
                            if (buffer_time[i] > 32'd0 && buffer_time[i] <= tech_available_time[min_index]) begin
                                // Check if already in queue
                                j <= 0;
                                for (min_index = 0; min_index < queue_size; min_index = min_index + 8'd1) begin
                                    if (ready_queue[min_index] == i) begin
                                        j <= 1;
                                    end
                                end
                                
                                if (j == 0) begin
                                    ready_queue[queue_size] <= i;
                                    queue_size <= queue_size + 8'd1;
                                end
                            end
                        end
                        
                        // Sort queue again
                        for (i = 0; i < queue_size - 8'd1; i = i + 1) begin
                            min_index <= i;
                            min_time <= buffer_time[ready_queue[i]];
                            min_type <= buffer_type[ready_queue[i]];
                            min_duration <= buffer_duration[ready_queue[i]];
                            
                            for (j = i + 8'd1; j < queue_size; j = j + 1) begin
                                if (buffer_type[ready_queue[j]] > min_type ||
                                    (buffer_type[ready_queue[j]] == min_type && 
                                     (buffer_time[ready_queue[j]] < min_time ||
                                      (buffer_time[ready_queue[j]] == min_time &&
                                       buffer_duration[ready_queue[j]] < min_duration)))) begin
                                    min_index <= j;
                                    min_time <= buffer_time[ready_queue[j]];
                                    min_type <= buffer_type[ready_queue[j]];
                                    min_duration <= buffer_duration[ready_queue[j]];
                                end
                            end
                            
                            // Swap
                            if (min_index != i) begin
                                j <= ready_queue[i];
                                ready_queue[i] <= ready_queue[min_index];
                                ready_queue[min_index] <= j;
                            end
                        end
                    end
                    
                    // Check if all prescriptions processed
                    if (queue_size == 8'd0) begin
                        state <= COMPUTE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Calculate averages
                    if (count_store > 8'd0) begin
                        avg_store <= sum_store[63:32] + (sum_store[31:0] >> 16);
                    end else begin
                        avg_store <= 32'd0;
                    end
                    
                    if (count_remote > 8'd0) begin
                        avg_remote <= sum_remote[63:32] + (sum_remote[31:0] >> 16);
                    end else begin
                        avg_remote <= 32'd0;
                    end
                    
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule