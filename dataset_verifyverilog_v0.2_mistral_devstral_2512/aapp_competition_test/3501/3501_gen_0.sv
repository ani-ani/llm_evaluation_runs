module camel_race_bets (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] a [0:31],
    input [4:0] b [0:31],
    input [4:0] c [0:31],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        CHECK_PAIRS,
        DONE
    } state_t;

    state_t state;
    reg [31:0] count;
    reg [4:0] pos_a [0:31];
    reg [4:0] pos_b [0:31];
    reg [4:0] pos_c [0:31];
    reg [4:0] i, j;
    reg [4:0] setup_idx;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            i <= 0;
            j <= 0;
            setup_idx <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SETUP;
                        setup_idx <= 0;
                        count <= 0;
                        done <= 0;
                    end
                end
                SETUP: begin
                    // Build position lookup tables
                    if (setup_idx < n) begin
                        pos_a[a[setup_idx]] <= setup_idx;
                        pos_b[b[setup_idx]] <= setup_idx;
                        pos_c[c[setup_idx]] <= setup_idx;
                        setup_idx <= setup_idx + 1;
                    end else begin
                        state <= CHECK_PAIRS;
                        i <= 1;
                        j <= 2;
                    end
                end
                CHECK_PAIRS: begin
                    if (i < n) begin
                        if (j < n) begin
                            // Check if pair (i,j) is consistent in all bets
                            if (pos_a[i] < pos_a[j] && pos_b[i] < pos_b[j] && pos_c[i] < pos_c[j]) begin
                                count <= count + 1;
                            end
                            j <= j + 1;
                        end else begin
                            i <= i + 1;
                            j <= i + 1;
                        end
                    end else begin
                        state <= DONE;
                        result <= count;
                        done <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule