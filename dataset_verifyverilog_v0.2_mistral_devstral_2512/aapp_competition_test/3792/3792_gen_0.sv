module fair_nut_strings (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_s,
    input [7:0] char_t,
    input [31:0] k,
    output reg [31:0] result,
    output reg done,
    output reg [7:0] char_idx
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        READ_CHAR,
        COMPUTE,
        ACCUMULATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] cur_count;
    reg [31:0] total_sum;
    reg [7:0] idx;
    reg [7:0] n;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            cur_count <= 1;
            total_sum <= 0;
            idx <= 0;
            n <= 100;
            result <= 0;
            done <= 0;
            char_idx <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = READ_CHAR;
            end
            READ_CHAR: begin
                if (idx < n - 1) next_state = COMPUTE;
                else next_state = ACCUMULATE;
            end
            COMPUTE: begin
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                if (idx < n - 1) next_state = READ_CHAR;
                else next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cur_count <= 1;
            total_sum <= 0;
            idx <= 0;
            result <= 0;
            done <= 0;
            char_idx <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        cur_count <= 1;
                        total_sum <= 0;
                        idx <= 0;
                        done <= 0;
                        char_idx <= 0;
                    end
                end
                READ_CHAR: begin
                    char_idx <= idx;
                    idx <= idx + 1;
                end
                COMPUTE: begin
                    if (char_s == char_t) begin
                        cur_count <= cur_count;
                    end else begin
                        cur_count <= (cur_count * 2) + 1;
                        if (cur_count > k) cur_count <= k;
                    end
                end
                ACCUMULATE: begin
                    total_sum <= total_sum + cur_count;
                    if (idx == n - 1) begin
                        result <= total_sum;
                        done <= 1;
                    end
                end
                DONE: begin
                    done <= 1;
                end
                default: ;
            endcase
        end
    end

endmodule