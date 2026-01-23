module armstrong_checker(
    input clk,
    input rst_n,
    input start,
    input [9:0] number,
    output reg result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        COUNT_DIGITS,
        EXTRACT_DIGITS,
        CHECK_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [9:0] original_num;
    reg [9:0] working_num;
    reg [9:0] sum;
    reg [3:0] digit_count;
    reg [3:0] current_digit;
    reg [9:0] digit_cube;

    // Cubes lookup table for digits 0-9
    wire [9:0] cube_table [0:9] = '{0, 1, 8, 27, 64, 125, 216, 343, 512, 729};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            original_num <= 0;
            working_num <= 0;
            sum <= 0;
            digit_count <= 0;
            current_digit <= 0;
            digit_cube <= 0;
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
                    next_state = COUNT_DIGITS;
                end
            end
            COUNT_DIGITS: begin
                next_state = EXTRACT_DIGITS;
            end
            EXTRACT_DIGITS: begin
                if (digit_count == 0) begin
                    next_state = CHECK_RESULT;
                end
            end
            CHECK_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            original_num <= 0;
            working_num <= 0;
            sum <= 0;
            digit_count <= 0;
            current_digit <= 0;
            digit_cube <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        original_num <= number;
                        working_num <= number;
                        sum <= 0;
                        digit_count <= 0;
                        current_digit <= 0;
                        digit_cube <= 0;
                    end
                end
                COUNT_DIGITS: begin
                    // Count digits (only 3-digit numbers are considered)
                    if (number >= 100) begin
                        digit_count <= 3;
                    end else begin
                        digit_count <= 0; // Not a 3-digit number
                    end
                end
                EXTRACT_DIGITS: begin
                    if (digit_count > 0) begin
                        current_digit <= working_num % 10;
                        digit_cube <= cube_table[current_digit];
                        sum <= sum + digit_cube;
                        working_num <= working_num / 10;
                        digit_count <= digit_count - 1;
                    end
                end
                CHECK_RESULT: begin
                    if (sum == original_num) begin
                        result <= 1;
                    end else begin
                        result <= 0;
                    end
                end
                DONE: begin
                    done <= 1;
                end
                default: ;
            endcase
        end
    end

    // Reset done signal when leaving DONE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state != DONE) begin
            done <= 0;
        end
    end

endmodule