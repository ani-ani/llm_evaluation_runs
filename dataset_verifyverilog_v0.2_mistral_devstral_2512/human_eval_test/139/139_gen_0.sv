module special_factorial (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        CALCULATE_FACTORIALS,
        MULTIPLY_RESULTS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] temp_factorial;
    reg [31:0] current_product;
    reg [3:0] current_i;
    reg [3:0] factorial_counter;
    reg [31:0] factorial_result;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            temp_factorial <= 32'b0;
            current_product <= 32'b0;
            current_i <= 4'b0;
            factorial_counter <= 4'b0;
            factorial_result <= 32'b0;
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
                    next_state = CALCULATE_FACTORIALS;
                end
            end
            CALCULATE_FACTORIALS: begin
                if (factorial_counter == current_i) begin
                    if (current_i == n) begin
                        next_state = MULTIPLY_RESULTS;
                    end else begin
                        current_i <= current_i + 1'b1;
                        factorial_counter <= 1'b0;
                        factorial_result <= 1'b1;
                    end
                end
            end
            MULTIPLY_RESULTS: begin
                if (current_i == 1'b0) begin
                    next_state = DONE;
                end
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
            // Reset values already handled in state transition
        end else begin
            case (current_state)
                IDLE: begin
                    result <= 32'b1;
                    done <= 1'b0;
                    current_i <= 1'b1;
                    factorial_counter <= 1'b0;
                    factorial_result <= 32'b1;
                    current_product <= 32'b1;
                end
                CALCULATE_FACTORIALS: begin
                    if (factorial_counter == 1'b0) begin
                        factorial_result <= 1'b1;
                    end else begin
                        factorial_result <= factorial_result * factorial_counter;
                    end
                    factorial_counter <= factorial_counter + 1'b1;
                end
                MULTIPLY_RESULTS: begin
                    current_product <= current_product * temp_factorial;
                    if (current_i == 1'b1) begin
                        result <= current_product;
                        done <= 1'b1;
                    end
                    current_i <= current_i - 1'b1;
                end
                DONE: begin
                    // Hold values
                end
                default:;
            endcase
        end
    end

    // Store factorial result when computation completes
    always @(posedge clk) begin
        if (current_state == CALCULATE_FACTORIALS && factorial_counter == current_i) begin
            temp_factorial <= factorial_result;
        end
    end

endmodule