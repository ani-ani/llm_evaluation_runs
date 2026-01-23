module pharmacy_sim (
    input clk,
    input rst_n,
    input start,
    input [63:0] in_drop_time [7:0],
    input [7:0] in_type [7:0],
    input [31:0] in_fill_time [7:0],
    input [2:0] valid_count,
    output reg [63:0] avg_in_store_time,
    output reg [63:0] avg_remote_time,
    output reg done
);

    // Parameters
    localparam N = 8; // Max prescriptions
    localparam T = 4; // Max technicians

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;
    state_t current_state, next_state;

    // Internal registers
    reg [63:0] current_time;
    reg [63:0] in_store_sum;
    reg [63:0] remote_sum;
    reg [3:0] in_store_count;
    reg [3:0] remote_count;
    reg [3:0] busy_technicians;
    reg [3:0] next_prescription;
    reg [3:0] next_technician;
    reg [63:0] next_event_time;
    reg [63:0] completion_time;

    // Event queue (simplified for small N)
    reg [63:0] event_times [0:N-1];
    reg [7:0] event_types [0:N-1];
    reg [31:0] event_fill_times [0:N-1];
    reg [3:0] event_indices [0:N-1];
    reg [3:0] event_count;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_time <= 0;
            in_store_sum <= 0;
            remote_sum <= 0;
            in_store_count <= 0;
            remote_count <= 0;
            busy_technicians <= 0;
            next_prescription <= 0;
            next_technician <= 0;
            next_event_time <= 0;
            completion_time <= 0;
            event_count <= 0;
            done <= 0;
            avg_in_store_time <= 0;
            avg_remote_time <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    // Initialize event queue with drop times
                    for (int i = 0; i < N; i = i + 1) begin
                        if (i < valid_count) begin
                            event_times[i] = in_drop_time[i];
                            event_types[i] = in_type[i];
                            event_fill_times[i] = in_fill_time[i];
                            event_indices[i] = i;
                        end else begin
                            event_times[i] = 64'hFFFFFFFFFFFFFFFF;
                            event_types[i] = 0;
                            event_fill_times[i] = 0;
                            event_indices[i] = 0;
                        end
                    end
                    event_count = valid_count;
                    current_time = 0;
                    in_store_sum = 0;
                    remote_sum = 0;
                    in_store_count = 0;
                    remote_count = 0;
                    busy_technicians = 0;
                    done = 0;
                end
            end
            PROCESSING: begin
                // Check if all events are processed
                if (event_count == 0 && busy_technicians == 0) begin
                    next_state = DONE;
                    // Calculate averages
                    if (in_store_count > 0) begin
                        avg_in_store_time = in_store_sum / in_store_count;
                    end else begin
                        avg_in_store_time = 0;
                    end
                    if (remote_count > 0) begin
                        avg_remote_time = remote_sum / remote_count;
                    end else begin
                        avg_remote_time = 0;
                    end
                    done = 1;
                end else begin
                    // Find next event time
                    next_event_time = 64'hFFFFFFFFFFFFFFFF;
                    for (int i = 0; i < event_count; i = i + 1) begin
                        if (event_times[i] < next_event_time) begin
                            next_event_time = event_times[i];
                        end
                    end
                    // Advance time to next event
                    current_time = next_event_time;
                    // Process events at this time
                    for (int i = 0; i < event_count; i = i + 1) begin
                        if (event_times[i] == current_time) begin
                            // Assign to technician if available
                            if (busy_technicians < T) begin
                                // Find next available technician
                                next_technician = 0;
                                while (next_technician < T && (busy_technicians & (1 << next_technician))) begin
                                    next_technician = next_technician + 1;
                                end
                                if (next_technician < T) begin
                                    busy_technicians = busy_technicians | (1 << next_technician);
                                    // Schedule completion event
                                    completion_time = current_time + event_fill_times[i];
                                    // Add to event queue
                                    event_times[event_count] = completion_time;
                                    event_types[event_count] = event_types[i];
                                    event_fill_times[event_count] = event_fill_times[i];
                                    event_indices[event_count] = event_indices[i];
                                    event_count = event_count + 1;
                                end
                            end
                            // Remove this event
                            for (int j = i; j < event_count - 1; j = j + 1) begin
                                event_times[j] = event_times[j + 1];
                                event_types[j] = event_types[j + 1];
                                event_fill_times[j] = event_fill_times[j + 1];
                                event_indices[j] = event_indices[j + 1];
                            end
                            event_count = event_count - 1;
                            i = i - 1; // Adjust index after removal
                        end
                    end
                    // Check for completion events
                    for (int i = 0; i < event_count; i = i + 1) begin
                        if (event_times[i] == current_time) begin
                            // Technician becomes free
                            busy_technicians = busy_technicians & ~(1 << next_technician);
                            // Calculate completion time
                            if (event_types[i] == 1) begin
                                in_store_sum = in_store_sum + (current_time - in_drop_time[event_indices[i]]);
                                in_store_count = in_store_count + 1;
                            end else begin
                                remote_sum = remote_sum + (current_time - in_drop_time[event_indices[i]]);
                                remote_count = remote_count + 1;
                            end
                            // Remove this event
                            for (int j = i; j < event_count - 1; j = j + 1) begin
                                event_times[j] = event_times[j + 1];
                                event_types[j] = event_types[j + 1];
                                event_fill_times[j] = event_fill_times[j + 1];
                                event_indices[j] = event_indices[j + 1];
                            end
                            event_count = event_count - 1;
                            i = i - 1; // Adjust index after removal
                        end
                    end
                end
            end
            DONE: begin
                // Stay in DONE state
            end
        endcase
    end

endmodule