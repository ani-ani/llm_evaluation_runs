module interleaving_verifier (
    input clk,
    input rst_n,
    input start,
    input [5:0] len_s,
    input [5:0] len_s1,
    input [5:0] len_s2,
    input [7:0] s [15:0],
    input [7:0] s1 [7:0],
    input [7:0] s2 [7:0],
    output reg result,
    output reg done
);

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        PROCESSING_ROW,
        PROCESSING_COL,
        DONE
    } state_t;

    state_t current_state, next_state;

    // DP state array (9x9)
    reg [8:0][8:0] state;

    // Counters for i and j
    reg [3:0] i, j;

    // Initialize state array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            i <= 0;
            j <= 0;
        end else begin
            current_state <= next_state;
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state = INIT;
                    end
                end
                INIT: begin
                    // Initialize state[0][0] = 1
                    state[0][0] = 1;
                    i <= 0;
                    j <= 0;
                    next_state = PROCESSING_ROW;
                end
                PROCESSING_ROW: begin
                    if (i < len_s1 && state[i][j] && s[i+j] == s1[i]) begin
                        state[i+1][j] = 1;
                    end
                    if (j < len_s2 && state[i][j] && s[i+j] == s2[j]) begin
                        state[i][j+1] = 1;
                    end
                    if (j < len_s2) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < len_s1) begin
                            i <= i + 1;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
                DONE: begin
                    result <= state[len_s1][len_s2];
                    done <= 1;
                end
                default: begin
                    next_state = IDLE;
                end
            endcase
        end
    end

    // Default state for next_state
    always @(*) begin
        next_state = current_state;
    end

endmodule