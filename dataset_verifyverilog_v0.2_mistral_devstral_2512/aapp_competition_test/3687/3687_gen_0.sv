module downlink_verifier (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] q_in,
    input [3:0] s_in,
    input [3:0] sensor_queue_map [3:0],
    input [255:0] queue_capacities [3:0],
    input [255:0] window_downlink [3:0],
    input [255:0] sensor_data [3:0][3:0],
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        READ_PARAMS,
        PROCESS_WINDOW,
        CHECK_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] window_count;
    reg [3:0] sensor_count;
    reg [3:0] queue_count;
    reg [255:0] queue_levels [3:0];
    reg overflow_detected;
    reg [255:0] remaining_downlink;

    // Fixed-point arithmetic helpers
    function [255:0] add_q16_16;
        input [255:0] a, b;
        begin
            add_q16_16 = a + b;
        end
    endfunction

    function [255:0] sub_q16_16;
        input [255:0] a, b;
        begin
            sub_q16_16 = a - b;
        end
    endfunction

    function logic is_overflow;
        input [255:0] fill, data, capacity;
        begin
            is_overflow = (fill + data) > capacity;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            window_count <= 0;
            sensor_count <= 0;
            queue_count <= 0;
            overflow_detected <= 0;
            for (int i = 0; i < 4; i++) begin
                queue_levels[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = READ_PARAMS;
                end
            end
            READ_PARAMS: begin
                next_state = PROCESS_WINDOW;
            end
            PROCESS_WINDOW: begin
                if (overflow_detected) begin
                    next_state = DONE;
                end else if (window_count == n_in - 1) begin
                    next_state = CHECK_RESULT;
                end
            end
            CHECK_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                READ_PARAMS: begin
                    // Initialize queue levels
                    for (int i = 0; i < 4; i++) begin
                        queue_levels[i] <= 0;
                    end
                    window_count <= 0;
                    sensor_count <= 0;
                    queue_count <= 0;
                    overflow_detected <= 0;
                end
                PROCESS_WINDOW: begin
                    // Process current window
                    if (sensor_count < s_in) begin
                        // Add sensor data to queues
                        reg [3:0] queue_idx = sensor_queue_map[sensor_count];
                        if (is_overflow(queue_levels[queue_idx], sensor_data[window_count][sensor_count], queue_capacities[queue_idx])) begin
                            overflow_detected <= 1;
                        end else begin
                            queue_levels[queue_idx] <= add_q16_16(queue_levels[queue_idx], sensor_data[window_count][sensor_count]);
                        end
                        sensor_count <= sensor_count + 1;
                    end else if (queue_count < q_in) begin
                        // Allocate downlink bandwidth
                        if (queue_levels[queue_count] > 0) begin
                            if (remaining_downlink == 0) begin
                                remaining_downlink <= window_downlink[window_count];
                            end
                            if (queue_levels[queue_count] <= remaining_downlink) begin
                                remaining_downlink <= sub_q16_16(remaining_downlink, queue_levels[queue_count]);
                                queue_levels[queue_count] <= 0;
                            end else begin
                                queue_levels[queue_count] <= sub_q16_16(queue_levels[queue_count], remaining_downlink);
                                remaining_downlink <= 0;
                            end
                        end
                        queue_count <= queue_count + 1;
                    end else begin
                        // Move to next window
                        window_count <= window_count + 1;
                        sensor_count <= 0;
                        queue_count <= 0;
                        remaining_downlink <= 0;
                    end
                end
                CHECK_RESULT: begin
                    // Check if all queues are empty
                    logic all_empty = 1;
                    for (int i = 0; i < 4; i++) begin
                        if (queue_levels[i] != 0) begin
                            all_empty = 0;
                        end
                    end
                    result <= all_empty && !overflow_detected;
                    done <= 1;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule