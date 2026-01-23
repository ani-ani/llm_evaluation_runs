module course_scheduler (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [3:0] valid_mask,
    input [9:0] course_difficulty_0_i,
    input [9:0] course_difficulty_0_ii,
    input [9:0] course_difficulty_1_i,
    input [9:0] course_difficulty_1_ii,
    input [9:0] course_difficulty_2_i,
    input [9:0] course_difficulty_2_ii,
    input [9:0] course_difficulty_3_i,
    input [9:0] course_difficulty_3_ii,
    output reg [15:0] min_sum,
    output reg done,
    output reg error
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] current_min_sum;
    reg [15:0] temp_sum;
    reg [3:0] temp_count;
    reg [3:0] combination;
    reg valid_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            error <= 0;
            min_sum <= 0;
            current_min_sum <= 16'hFFFF;
            combination <= 0;
            valid_found <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (combination == 15) begin
                    if (valid_found) next_state = DONE;
                    else next_state = IDLE;
                end
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
            temp_sum <= 0;
            temp_count <= 0;
        end else if (current_state == COMPUTE) begin
            // Calculate sum and count for current combination
            temp_sum = 0;
            temp_count = 0;

            // Pair 0
            if (combination[0]) begin
                temp_sum = temp_sum + course_difficulty_0_i;
                temp_count = temp_count + 1;
                if (combination[1]) begin
                    temp_sum = temp_sum + course_difficulty_0_ii;
                    temp_count = temp_count + 1;
                end
            end

            // Pair 1
            if (combination[2]) begin
                temp_sum = temp_sum + course_difficulty_1_i;
                temp_count = temp_count + 1;
                if (combination[3]) begin
                    temp_sum = temp_sum + course_difficulty_1_ii;
                    temp_count = temp_count + 1;
                end
            end

            // Pair 2
            if (combination[4]) begin
                temp_sum = temp_sum + course_difficulty_2_i;
                temp_count = temp_count + 1;
                if (combination[5]) begin
                    temp_sum = temp_sum + course_difficulty_2_ii;
                    temp_count = temp_count + 1;
                end
            end

            // Pair 3
            if (combination[6]) begin
                temp_sum = temp_sum + course_difficulty_3_i;
                temp_count = temp_count + 1;
                if (combination[7]) begin
                    temp_sum = temp_sum + course_difficulty_3_ii;
                    temp_count = temp_count + 1;
                end
            end

            // Check if this combination is valid
            if (temp_count == k) begin
                if (temp_sum < current_min_sum) begin
                    current_min_sum <= temp_sum;
                    valid_found <= 1;
                end
            end

            // Increment combination counter
            combination <= combination + 1;
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            error <= 0;
            min_sum <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    min_sum <= 0;
                end
                COMPUTE: begin
                    done <= 0;
                    error <= 0;
                end
                DONE: begin
                    done <= 1;
                    error <= !valid_found;
                    min_sum <= current_min_sum;
                end
                default: begin
                    done <= 0;
                    error <= 0;
                    min_sum <= 0;
                end
            endcase
        end
    end

endmodule