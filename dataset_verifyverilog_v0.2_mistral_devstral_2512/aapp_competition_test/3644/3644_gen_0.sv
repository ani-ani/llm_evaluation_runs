module hr_optimization (
    input clk,
    input rst_n,
    input start,
    input [5:0] hire_count,
    input [5:0] fire_count,
    input valid_in,
    input last_day,
    output reg [2:0] hr_id_out,
    output reg [3:0] day_index_out,
    output reg valid_out,
    output reg [2:0] min_hr_count,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        READ_DAY,
        PROCESS_FIRE,
        PROCESS_HIRE,
        UPDATE_OUT,
        CHECK_DONE
    } state_t;

    state_t current_state, next_state;

    // Worker stack and pointer
    reg [2:0] worker_stack [0:63];
    reg [5:0] stack_ptr;

    // Day tracking
    reg [3:0] day_index;

    // Fired worker IDs buffer
    reg [2:0] fired_ids [0:7];
    reg [2:0] fire_buffer_ptr;

    // HR ID tracking
    reg [2:0] current_hr_id;
    reg [2:0] max_hr_id;

    // Counters for processing
    reg [2:0] fire_counter;
    reg [2:0] hire_counter;

    // Temporary variables
    reg [2:0] temp_id;
    reg [2:0] min_valid_id;
    reg id_valid;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            stack_ptr <= 0;
            day_index <= 0;
            fire_buffer_ptr <= 0;
            max_hr_id <= 0;
            fire_counter <= 0;
            hire_counter <= 0;
            hr_id_out <= 0;
            day_index_out <= 0;
            valid_out <= 0;
            min_hr_count <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = READ_DAY;
            end
            READ_DAY: begin
                if (valid_in) next_state = PROCESS_FIRE;
            end
            PROCESS_FIRE: begin
                if (fire_counter == fire_count) next_state = PROCESS_HIRE;
            end
            PROCESS_HIRE: begin
                if (hire_counter == hire_count) next_state = UPDATE_OUT;
            end
            UPDATE_OUT: begin
                next_state = CHECK_DONE;
            end
            CHECK_DONE: begin
                if (last_day) next_state = IDLE;
                else next_state = READ_DAY;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                PROCESS_FIRE: begin
                    if (fire_counter < fire_count) begin
                        fired_ids[fire_counter] = worker_stack[stack_ptr - 1];
                        stack_ptr <= stack_ptr - 1;
                        fire_counter <= fire_counter + 1;
                    end
                end
                PROCESS_HIRE: begin
                    if (hire_counter < hire_count) begin
                        // Find smallest valid HR ID
                        min_valid_id = 1;
                        id_valid = 0;
                        for (temp_id = 1; temp_id <= 4; temp_id = temp_id + 1) begin
                            id_valid = 1;
                            for (int i = 0; i < fire_count; i = i + 1) begin
                                if (fired_ids[i] == temp_id) begin
                                    id_valid = 0;
                                    break;
                                end
                            end
                            if (id_valid) begin
                                min_valid_id = temp_id;
                                break;
                            end
                        end
                        // If no valid ID, increment max_hr_id
                        if (!id_valid) begin
                            if (max_hr_id < 4) max_hr_id = max_hr_id + 1;
                            min_valid_id = max_hr_id;
                        end
                        // Update max_hr_id if needed
                        if (min_valid_id > max_hr_id) max_hr_id = min_valid_id;
                        // Push new worker with HR ID
                        worker_stack[stack_ptr] = min_valid_id;
                        stack_ptr <= stack_ptr + 1;
                        hire_counter <= hire_counter + 1;
                        current_hr_id = min_valid_id;
                    end
                end
                UPDATE_OUT: begin
                    hr_id_out <= current_hr_id;
                    day_index_out <= day_index;
                    valid_out <= 1;
                end
                CHECK_DONE: begin
                    valid_out <= 0;
                    if (last_day) begin
                        min_hr_count <= max_hr_id;
                        done <= 1;
                    end else begin
                        day_index <= day_index + 1;
                        fire_counter <= 0;
                        hire_counter <= 0;
                    end
                end
                READ_DAY: begin
                    done <= 0;
                end
            endcase
        end
    end

endmodule