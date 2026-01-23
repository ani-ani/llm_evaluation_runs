module turtle_dry_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] target_pattern,
    input [127:0] commands_packed,
    output reg [5:0] min_time,
    output reg [5:0] max_time,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        FETCH,
        CALCULATE,
        CHECK,
        NEXT,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [4:0] step_index; // 0-31
    reg [1:0] distance_remaining; // 0-3 (represents 1-4 steps)
    reg [1:0] direction; // 00=up, 01=right, 10=down, 11=left
    reg [1:0] x_pos; // 0-3
    reg [1:0] y_pos; // 0-3
    reg [15:0] current_marking; // 4x4 grid flattened
    reg [5:0] total_step_count; // 0-32
    reg [5:0] min_candidate; // 0-32
    reg [5:0] max_candidate; // 0-32
    reg found_valid; // At least one match found

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            step_index <= 0;
            distance_remaining <= 0;
            direction <= 0;
            x_pos <= 0;
            y_pos <= 0;
            current_marking <= 0;
            total_step_count <= 0;
            min_candidate <= 0;
            max_candidate <= 0;
            found_valid <= 0;
            min_time <= 0;
            max_time <= 0;
            valid <= 0;
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
                if (start) next_state = FETCH;
            end
            FETCH: begin
                next_state = CALCULATE;
            end
            CALCULATE: begin
                if (distance_remaining == 0) next_state = CHECK;
                else next_state = CALCULATE;
            end
            CHECK: begin
                next_state = NEXT;
            end
            NEXT: begin
                if (step_index == 31) next_state = FINISHED;
                else next_state = FETCH;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                FETCH: begin
                    // Extract command bits
                    distance_remaining <= commands_packed[(step_index * 4) + 3:(step_index * 4) + 2];
                    direction <= commands_packed[(step_index * 4) + 1:(step_index * 4)];
                end
                CALCULATE: begin
                    // Move one step
                    case (direction)
                        2'b00: y_pos <= y_pos + 1; // Up
                        2'b01: x_pos <= x_pos + 1; // Right
                        2'b10: y_pos <= y_pos - 1; // Down
                        2'b11: x_pos <= x_pos - 1; // Left
                    endcase
                    distance_remaining <= distance_remaining - 1;
                    total_step_count <= total_step_count + 1;
                    // Mark current cell
                    current_marking[(y_pos * 4) + x_pos] <= 1;
                end
                CHECK: begin
                    // Check if current_marking matches target_pattern
                    if (current_marking == target_pattern) begin
                        if (!found_valid) begin
                            min_candidate <= total_step_count;
                            max_candidate <= total_step_count;
                            found_valid <= 1;
                        end else begin
                            if (total_step_count < min_candidate) min_candidate <= total_step_count;
                            if (total_step_count > max_candidate) max_candidate <= total_step_count;
                        end
                    end
                end
                NEXT: begin
                    step_index <= step_index + 1;
                end
                FINISHED: begin
                    min_time <= min_candidate;
                    max_time <= max_candidate;
                    valid <= found_valid;
                    done <= 1;
                end
            endcase
        end
    end

endmodule