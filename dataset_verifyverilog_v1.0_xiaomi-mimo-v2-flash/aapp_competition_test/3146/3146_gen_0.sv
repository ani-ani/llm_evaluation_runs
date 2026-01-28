module pharmacy_prescription_filling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire presc_valid,
    input wire [31:0] presc_time,
    input wire presc_type,
    input wire [8:0] presc_duration,
    input wire [3:0] num_technicians,
    output reg busy,
    output reg done,
    output reg [31:0] avg_store,
    output reg [31:0] avg_remote,
    output reg error
);

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] LOAD_PRESC      = 4'd1;
    localparam [3:0] CHECK_TECH      = 4'd2;
    localparam [3:0] SORT_BUFFER     = 4'd3;
    localparam [3:0] PREPARE_QUEUE   = 4'd4;
    localparam [3:0] PROCESS_EVENT   = 4'd5;
    localparam [3:0] UPDATE_TECH     = 4'd6;
    localparam [3:0] CALC_AVG        = 4'd7;
    localparam [3:0] FINISH          = 4'd8;
    localparam [3:0] ERROR_STATE     = 4'd9;

    // Buffer entry structure
    localparam [9:0] BUFFER_SIZE = 10'd256;
    
    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] presc_count;           // Number of loaded prescriptions
    reg [9:0] buffer_index;          // Index for buffer operations
    reg [11:0] cycle_count;          // Bounded execution cycles
    
    // Buffer storage (unpacked array for Icarus compatibility)
    reg [31:0] buffer_time [0:255];
    reg buffer_type [0:255];
    reg [8:0] buffer_duration [0:255];
    
    // Queue storage (circular buffer for ready queue)
    reg [31:0] queue_time [0:255];
    reg queue_type [0:255];
    reg [8:0] queue_duration [0:255];
    reg [7:0] queue_head, queue_tail, queue_size;
    
    // Technician tracking
    reg [31:0] tech_free_time [0:9];  // Max 10 technicians
    reg [3:0] tech_count;
    
    // Processing state
    reg [31:0] current_time;
    reg [31:0] event_time;
    reg event_type;
    reg [8:0] event_duration;
    reg [31:0] sum_store_time, sum_remote_time;
    reg [15:0] count_store, count_remote;
    
    // Temporary registers for sorting/processing
    reg [31:0] temp_time;
    reg temp_type;
    reg [8:0] temp_duration;
    reg [7:0] temp_idx;
    reg [7:0] sort_i, sort_j;
    reg [31:0] earliest_time;
    reg earliest_idx;
    reg [3:0] tech_idx;
    reg [31:0] free_time;
    reg [31:0] completion_time;
    
    // Control flags
    reg loading_done;
    reg start_processing;
    reg all_processed;
    
    integer i, j, k;
    
    // Reset and state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            avg_store <= 32'd0;
            avg_remote <= 32'd0;
            presc_count <= 8'd0;
            buffer_index <= 10'd0;
            cycle_count <= 12'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_size <= 8'd0;
            current_time <= 32'd0;
            sum_store_time <= 32'd0;
            sum_remote_time <= 32'd0;
            count_store <= 16'd0;
            count_remote <= 16'd0;
            loading_done <= 1'b0;
            start_processing <= 1'b0;
            all_processed <= 1'b0;
            // Initialize buffer
            for (i = 0; i < 256; i = i + 1) begin
                buffer_time[i] <= 32'd0;
                buffer_type[i] <= 1'b0;
                buffer_duration[i] <= 9'd0;
            end
            // Initialize queue
            for (i = 0; i < 256; i = i + 1) begin
                queue_time[i] <= 32'd0;
                queue_type[i] <= 1'b0;
                queue_duration[i] <= 9'd0;
            end
            // Initialize tech
            for (i = 0; i < 10; i = i + 1) begin
                tech_free_time[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    presc_count <= 8'd0;
                    buffer_index <= 10'd0;
                    cycle_count <= 12'd0;
                    queue_head <= 8'd0;
                    queue_tail <= 8'd0;
                    queue_size <= 8'd0;
                    current_time <= 32'd0;
                    sum_store_time <= 32'd0;
                    sum_remote_time <= 32'd0;
                    count_store <= 16'd0;
                    count_remote <= 16'd0;
                    loading_done <= 1'b0;
                    start_processing <= 1'b0;
                    all_processed <= 1'b0;
                    busy <= 1'b0;
                end
                
                LOAD_PRESC: begin
                    if (presc_valid && buffer_index < BUFFER_SIZE) begin
                        buffer_time[buffer_index] <= presc_time;
                        buffer_type[buffer_index] <= presc_type;
                        buffer_duration[buffer_index] <= presc_duration;
                        buffer_index <= buffer_index + 10'd1;
                        presc_count <= presc_count + 8'd1;
                    end
                    if (start) begin
                        loading_done <= 1'b1;
                    end
                end
                
                CHECK_TECH: begin
                    tech_count <= num_technicians;
                    // Initialize tech availability
                    for (i = 0; i < 10; i = i + 1) begin
                        tech_free_time[i] <= 32'd0;
                    end
                end
                
                SORT_BUFFER: begin
                    // Selection sort (iterative) - bubble sort simulation
                    if (sort_i < presc_count - 8'd1) begin
                        if (sort_j < presc_count) begin
                            // Compare and swap logic
                            if (sort_j == sort_i + 8'd1) begin
                                // Initialize earliest
                                earliest_time <= buffer_time[sort_i];
                                temp_idx <= sort_i;
                                sort_j <= sort_j + 8'd1;
                            end else if (sort_j < presc_count) begin
                                // Compare current with earliest
                                if (buffer_time[sort_j] < earliest_time) begin
                                    earliest_time <= buffer_time[sort_j];
                                    temp_idx <= sort_j;
                                end else if (buffer_time[sort_j] == earliest_time && buffer_type[sort_j] > buffer_type[temp_idx]) begin
                                    // Same time: in-store first
                                    temp_idx <= sort_j;
                                end else if (buffer_time[sort_j] == earliest_time && buffer_type[sort_j] == buffer_type[temp_idx] && buffer_duration[sort_j] < buffer_duration[temp_idx]) begin
                                    // Same time, same type: shorter duration first
                                    temp_idx <= sort_j;
                                end
                                sort_j <= sort_j + 8'd1;
                            end
                            
                            // After iteration, swap if needed
                            if (sort_j >= presc_count && temp_idx != sort_i) begin
                                // Swap
                                temp_time <= buffer_time[sort_i];
                                temp_type <= buffer_type[sort_i];
                                temp_duration <= buffer_duration[sort_i];
                                buffer_time[sort_i] <= buffer_time[temp_idx];
                                buffer_type[sort_i] <= buffer_type[temp_idx];
                                buffer_duration[sort_i] <= buffer_duration[temp_idx];
                                buffer_time[temp_idx] <= temp_time;
                                buffer_type[temp_idx] <= temp_type;
                                buffer_duration[temp_idx] <= temp_duration;
                                sort_i <= sort_i + 8'd1;
                                sort_j <= sort_i + 8'd2;
                            end
                        end
                    end
                end
                
                PREPARE_QUEUE: begin
                    // Move all from buffer to queue
                    if (queue_size < presc_count) begin
                        queue_time[queue_tail] <= buffer_time[queue_size];
                        queue_type[queue_tail] <= buffer_type[queue_size];
                        queue_duration[queue_tail] <= buffer_duration[queue_size];
                        queue_tail <= queue_tail + 8'd1;
                        queue_size <= queue_size + 8'd1;
                    end
                end
                
                PROCESS_EVENT: begin
                    if (queue_size > 0 && cycle_count < 12'd2048) begin
                        // Get next event (head of queue)
                        event_time <= queue_time[queue_head];
                        event_type <= queue_type[queue_head];
                        event_duration <= queue_duration[queue_head];
                        // Remove from queue
                        queue_head <= queue_head + 8'd1;
                        queue_size <= queue_size - 8'd1;
                        
                        // Find earliest free technician
                        earliest_time <= 32'hFFFFFFFF;
                        for (i = 0; i < 10; i = i + 1) begin
                            if (i < tech_count) begin
                                if (tech_free_time[i] < earliest_time) begin
                                    earliest_time <= tech_free_time[i];
                                    earliest_idx <= i;
                                end
                            end
                        end
                    end
                    
                    if (queue_size == 0 && presc_count > 0) begin
                        all_processed <= 1'b1;
                    end
                end
                
                UPDATE_TECH: begin
                    if (cycle_count < 12'd2048 && queue_size == 0 && presc_count > 0) begin
                        // Calculate completion time
                        if (event_time > earliest_time) begin
                            free_time <= event_time;
                        end else begin
                            free_time <= earliest_time;
                        end
                        completion_time <= free_time + {23'd0, event_duration};
                        tech_free_time[earliest_idx] <= free_time + {23'd0, event_duration};
                        
                        // Update sums
                        if (event_type == 1'b1) begin
                            sum_store_time <= sum_store_time + completion_time;
                            count_store <= count_store + 16'd1;
                        end else begin
                            sum_remote_time <= sum_remote_time + completion_time;
                            count_remote <= count_remote + 16'd1;
                        end
                        
                        cycle_count <= cycle_count + 12'd1;
                    end
                end
                
                CALC_AVG: begin
                    // Calculate Q16.16 averages
                    if (count_store > 16'd0) begin
                        avg_store <= (sum_store_time << 16) / count_store;
                    end
                    if (count_remote > 16'd0) begin
                        avg_remote <= (sum_remote_time << 16) / count_remote;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    busy <= 1'b0;
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
                if (presc_valid) begin
                    next_state = LOAD_PRESC;
                end
            end
            
            LOAD_PRESC: begin
                if (loading_done) begin
                    next_state = CHECK_TECH;
                end
            end
            
            CHECK_TECH: begin
                if (num_technicians == 4'd0) begin
                    next_state = ERROR_STATE;
                end else if (presc_count > 8'd0) begin
                    next_state = SORT_BUFFER;
                end else begin
                    next_state = FINISH;
                end
            end
            
            SORT_BUFFER: begin
                // Sort completion check
                if (sort_i >= presc_count - 8'd1 && sort_j >= presc_count) begin
                    next_state = PREPARE_QUEUE;
                end
            end
            
            PREPARE_QUEUE: begin
                if (queue_size >= presc_count) begin
                    next_state = PROCESS_EVENT;
                end
            end
            
            PROCESS_EVENT: begin
                if (queue_size == 0 && presc_count == 0) begin
                    next_state = CALC_AVG;
                end else if (queue_size > 0 && cycle_count < 12'd2048) begin
                    next_state = UPDATE_TECH;
                end else if (queue_size == 0 && presc_count > 0 && cycle_count >= 12'd2048) begin
                    // Cycle limit reached
                    next_state = CALC_AVG;
                end
            end
            
            UPDATE_TECH: begin
                next_state = PROCESS_EVENT;
            end
            
            CALC_AVG: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            ERROR_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Busy signal logic
    always @(*) begin
        if (state == LOAD_PRESC || state == CHECK_TECH || state == SORT_BUFFER || 
            state == PREPARE_QUEUE || state == PROCESS_EVENT || state == UPDATE_TECH ||
            state == CALC_AVG || state == ERROR_STATE) begin
            busy = 1'b1;
        end else begin
            busy = 1'b0;
        end
    end
    
endmodule