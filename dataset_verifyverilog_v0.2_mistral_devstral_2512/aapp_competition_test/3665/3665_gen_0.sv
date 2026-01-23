module lossy_sort(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [2:0] m,
    input [9:0] current_number,
    input load,
    output reg [9:0] result_number,
    output reg [7:0] changes_count,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        COMPUTE,
        OUTPUT,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [9:0] prev_value;
    reg [7:0] total_changes;
    reg [2:0] position_counter;
    reg [9:0] current_input;
    reg [9:0] current_output;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                if (load) next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                if (position_counter == n) next_state = DONE;
                else next_state = LOAD;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_value <= 0;
            total_changes <= 0;
            position_counter <= 0;
            current_input <= 0;
            current_output <= 0;
            result_number <= 0;
            changes_count <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    prev_value <= 0;
                    total_changes <= 0;
                    position_counter <= 0;
                    current_input <= 0;
                    current_output <= 0;
                    result_number <= 0;
                    changes_count <= 0;
                    done <= 0;
                end
                LOAD: begin
                    if (load) begin
                        current_input <= current_number;
                    end
                end
                COMPUTE: begin
                    // Compute minimal changes
                    reg [9:0] min_val = prev_value;
                    reg [7:0] min_changes = 8'hFF;
                    reg [9:0] candidate;
                    reg [7:0] candidate_changes;

                    // Brute force search from prev_value to 999
                    for (int i = prev_value; i <= 999; i++) begin
                        candidate_changes = digit_changes(current_input, i);
                        if (candidate_changes < min_changes) begin
                            min_changes = candidate_changes;
                            min_val = i;
                        end
                    end

                    current_output <= min_val;
                    total_changes <= total_changes + min_changes;
                    prev_value <= min_val;
                end
                OUTPUT: begin
                    result_number <= current_output;
                    changes_count <= total_changes;
                    if (position_counter == n) begin
                        done <= 1;
                    end else begin
                        position_counter <= position_counter + 1;
                    end
                end
                DONE: begin
                    done <= 1;
                end
                default: ;
            endcase
        end
    end

    // Digit changes calculation function
    function [7:0] digit_changes(input [9:0] x, input [9:0] y);
        reg [7:0] changes = 0;
        reg [9:0] x_digits[0:2];
        reg [9:0] y_digits[0:2];

        // Extract digits
        x_digits[0] = x / 100;
        x_digits[1] = (x % 100) / 10;
        x_digits[2] = x % 10;

        y_digits[0] = y / 100;
        y_digits[1] = (y % 100) / 10;
        y_digits[2] = y % 10;

        // Count differing digits
        for (int i = 0; i < 3; i++) begin
            if (x_digits[i] != y_digits[i]) begin
                changes = changes + 1;
            end
        end

        digit_changes = changes;
    endfunction

endmodule