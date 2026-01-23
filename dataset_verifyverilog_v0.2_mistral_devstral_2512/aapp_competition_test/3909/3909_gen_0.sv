module unlucky_buyer (
    input clk,
    input rst_n,
    input start,
    input [63:0] n,
    output reg [63:0] result,
    output reg done
);

    // Define states
    typedef enum logic [1:0] {
        IDLE,
        CHECK_REMAINDER,
        UPDATE_N,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [63:0] current_n;
    reg [5:0] k;
    reg [63:0] original_n;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            current_n <= 64'd0;
            k <= 6'd0;
            original_n <= 64'd0;
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
                    next_state = CHECK_REMAINDER;
                    original_n = n;
                    current_n = n;
                    k = 6'd0;
                    done = 1'b0;
                end
            end
            CHECK_REMAINDER: begin
                if (current_n % 3 == 0) begin
                    next_state = UPDATE_N;
                end else begin
                    next_state = DONE;
                end
            end
            UPDATE_N: begin
                next_state = CHECK_REMAINDER;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 64'd0;
            done <= 1'b0;
        end else begin
            case (current_state)
                UPDATE_N: begin
                    current_n <= current_n / 3;
                    k <= k + 1;
                end
                DONE: begin
                    result <= current_n + 1;
                    done <= 1'b1;
                end
                default: begin
                    result <= 64'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule