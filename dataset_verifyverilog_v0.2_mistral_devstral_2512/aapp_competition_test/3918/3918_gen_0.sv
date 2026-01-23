module min_error_calculator (
    input clk,
    input rst_n,
    input start,
    input [5:0] k_total,
    input [2:0] n,
    input signed [15:0] a [0:7],
    input signed [15:0] b [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        COMPUTE_DIFF,
        FIND_MAX,
        UPDATE,
        CALCULATE_RESULT,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [15:0] d [0:7]; // Differences
    reg [2:0] max_idx; // Index of current max difference
    reg [5:0] op_count; // Operation counter
    reg [2:0] i; // Loop counter
    reg [31:0] sum_sq; // Sum of squares

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            op_count <= 0;
            i <= 0;
            max_idx <= 0;
            sum_sq <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_DIFF;
            end
            COMPUTE_DIFF: begin
                next_state = FIND_MAX;
            end
            FIND_MAX: begin
                if (i == n-1) begin
                    if (op_count < k_total) next_state = UPDATE;
                    else next_state = CALCULATE_RESULT;
                end
            end
            UPDATE: begin
                next_state = FIND_MAX;
            end
            CALCULATE_RESULT: begin
                if (i == n-1) next_state = DONE;
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
            // Reset all registers
            for (int j = 0; j < 8; j = j + 1) begin
                d[j] <= 0;
            end
            op_count <= 0;
            i <= 0;
            max_idx <= 0;
            sum_sq <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end
                COMPUTE_DIFF: begin
                    for (int j = 0; j < 8; j = j + 1) begin
                        if (j < n) begin
                            d[j] <= (a[j] > b[j]) ? (a[j] - b[j]) : (b[j] - a[j]);
                        end else begin
                            d[j] <= 0;
                        end
                    end
                    i <= 0;
                    max_idx <= 0;
                    op_count <= 0;
                end
                FIND_MAX: begin
                    if (i == 0) begin
                        max_idx <= 0;
                    end else if (d[i] > d[max_idx]) begin
                        max_idx <= i;
                    end
                    i <= i + 1;
                end
                UPDATE: begin
                    if (d[max_idx] > 0) begin
                        d[max_idx] <= d[max_idx] - 1;
                    end else begin
                        d[max_idx] <= 1;
                    end
                    op_count <= op_count + 1;
                    i <= 0;
                end
                CALCULATE_RESULT: begin
                    if (i == 0) begin
                        sum_sq <= 0;
                    end else if (i < n) begin
                        sum_sq <= sum_sq + (d[i-1] * d[i-1]);
                    end
                    i <= i + 1;
                end
                DONE: begin
                    done <= 1;
                    result <= sum_sq;
                end
                default: ;
            endcase
        end
    end

endmodule