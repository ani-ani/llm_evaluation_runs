module multiples_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] X,
    input [7:0] A,
    input [13:0] B,
    input [9:0] allowed,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        CHECK,
        CHECK_DIGITS,
        INCREMENT,
        COMPLETE
    } state_t;

    state_t current_state, next_state;
    reg [13:0] current_num;
    reg [13:0] temp_num;
    reg [3:0] digit;
    reg valid_digits;
    reg [3:0] digit_check_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            current_num <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (current_num > B) begin
                    next_state = COMPLETE;
                end else if (current_num % X == 0) begin
                    next_state = CHECK_DIGITS;
                end else begin
                    next_state = INCREMENT;
                end
            end
            CHECK_DIGITS: begin
                next_state = INCREMENT;
            end
            INCREMENT: begin
                next_state = CHECK;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_num <= 0;
            temp_num <= 0;
            digit <= 0;
            valid_digits <= 0;
            digit_check_state <= 0;
        end else begin
            case (current_state)
                INIT: begin
                    current_num <= A;
                    result <= 0;
                    done <= 0;
                end
                CHECK_DIGITS: begin
                    // Initialize digit check
                    if (digit_check_state == 0) begin
                        temp_num <= current_num;
                        valid_digits <= 1;
                        digit_check_state <= 1;
                    end else begin
                        // Perform digit check
                        if (temp_num > 0) begin
                            digit <= temp_num % 10;
                            if (!allowed[digit]) begin
                                valid_digits <= 0;
                            end
                            temp_num <= temp_num / 10;
                        end else begin
                            // Digit check complete
                            if (valid_digits) begin
                                result <= result + 1;
                            end
                            digit_check_state <= 0;
                        end
                    end
                end
                INCREMENT: begin
                    current_num <= current_num + 1;
                end
                COMPLETE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule