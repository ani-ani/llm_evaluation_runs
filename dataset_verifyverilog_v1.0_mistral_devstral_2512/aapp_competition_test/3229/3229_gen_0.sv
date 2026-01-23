module WorstRank (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_minus_one,
    input wire scores_valid,
    input wire [7:0] scores_in,
    input wire is_your_score,
    input wire end_of_contestants,
    output reg [7:0] worst_rank,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_YOUR_SCORES = 2'd1;
    localparam [1:0] READ_OTHER_SCORES = 2'd2;
    localparam [1:0] COMPUTE = 2'd3;
    localparam [1:0] DONE_STATE = 2'd4;

    reg [1:0] state, next_state;
    reg [3:0] score_index;
    reg [3:0] contestants_read;
    reg [7:0] your_scores [0:9];
    reg [7:0] other_scores [0:9];
    reg [15:0] your_aggregate;
    reg [15:0] other_aggregate;
    reg [7:0] fourth_highest;
    reg [15:0] needed_score;
    reg [7:0] counter;
    reg processing_you;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            score_index <= 4'd0;
            contestants_read <= 4'd0;
            your_aggregate <= 16'd0;
            other_aggregate <= 16'd0;
            fourth_highest <= 8'd0;
            needed_score <= 16'd0;
            counter <= 8'd0;
            processing_you <= 1'b1;
            worst_rank <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_YOUR_SCORES;
                end else begin
                    next_state = IDLE;
                end
            end

            READ_YOUR_SCORES: begin
                if (scores_valid) begin
                    if (score_index + 1 == n_minus_one) begin
                        next_state = READ_OTHER_SCORES;
                    end else begin
                        next_state = READ_YOUR_SCORES;
                    end
                end else begin
                    next_state = READ_YOUR_SCORES;
                end
            end

            READ_OTHER_SCORES: begin
                if (scores_valid) begin
                    if (score_index + 1 == n_minus_one) begin
                        if (end_of_contestants) begin
                            next_state = COMPUTE;
                        end else begin
                            next_state = READ_OTHER_SCORES;
                        end
                    end else begin
                        next_state = READ_OTHER_SCORES;
                    end
                end else begin
                    next_state = READ_OTHER_SCORES;
                end
            end

            COMPUTE: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                READ_YOUR_SCORES: begin
                    if (scores_valid) begin
                        your_scores[score_index] <= scores_in;
                        if (score_index + 1 == n_minus_one) begin
                            // Compute your aggregate
                            integer i, j;
                            reg [7:0] sorted[0:9];
                            for (i = 0; i < n_minus_one; i = i + 1) begin
                                sorted[i] = your_scores[i];
                            end
                            for (i = 0; i < n_minus_one - 1; i = i + 1) begin
                                for (j = 0; j < n_minus_one - i - 1; j = j + 1) begin
                                    if (sorted[j] < sorted[j + 1]) begin
                                        sorted[j] = sorted[j] ^ sorted[j + 1];
                                        sorted[j + 1] = sorted[j] ^ sorted[j + 1];
                                        sorted[j] = sorted[j] ^ sorted[j + 1];
                                    end
                                end
                            end
                            your_aggregate = 16'd0;
                            for (i = 0; i < (n_minus_one < 4 ? n_minus_one : 4); i = i + 1) begin
                                your_aggregate = your_aggregate + sorted[i];
                            end
                            fourth_highest = (n_minus_one >= 4) ? sorted[3] : 8'd0;
                            score_index <= 4'd0;
                            processing_you <= 1'b0;
                        end else begin
                            score_index <= score_index + 1;
                        end
                    end
                end

                READ_OTHER_SCORES: begin
                    if (scores_valid) begin
                        other_scores[score_index] <= scores_in;
                        if (score_index + 1 == n_minus_one) begin
                            // Compute other aggregate
                            integer i, j;
                            reg [7:0] sorted[0:9];
                            for (i = 0; i < n_minus_one; i = i + 1) begin
                                sorted[i] = other_scores[i];
                            end
                            for (i = 0; i < n_minus_one - 1; i = i + 1) begin
                                for (j = 0; j < n_minus_one - i - 1; j = j + 1) begin
                                    if (sorted[j] < sorted[j + 1]) begin
                                        sorted[j] = sorted[j] ^ sorted[j + 1];
                                        sorted[j + 1] = sorted[j] ^ sorted[j + 1];
                                        sorted[j] = sorted[j] ^ sorted[j + 1];
                                    end
                                end
                            end
                            other_aggregate = 16'd0;
                            for (i = 0; i < (n_minus_one < 4 ? n_minus_one : 4); i = i + 1) begin
                                other_aggregate = other_aggregate + sorted[i];
                            end
                            fourth_highest = (n_minus_one >= 4) ? sorted[3] : 8'd0;
                            // Compute needed score
                            if (n_minus_one < 4) begin
                                needed_score = (your_aggregate >= other_aggregate) ? (your_aggregate - other_aggregate + 1) : 16'd0;
                            end else begin
                                if (other_aggregate > your_aggregate) begin
                                    needed_score = 16'd0;
                                end else begin
                                    reg [15:0] val1 = fourth_highest + 1;
                                    reg [15:0] val2 = your_aggregate - other_aggregate + fourth_highest + 1;
                                    needed_score = (val1 > val2) ? val1 : val2;
                                end
                            end
                            // Update counter
                            if (needed_score <= 16'd101) begin
                                counter <= counter + 1;
                            end
                            score_index <= 4'd0;
                            contestants_read <= contestants_read + 1;
                        end else begin
                            score_index <= score_index + 1;
                        end
                    end
                end

                COMPUTE: begin
                    worst_rank <= counter + 1;
                    done <= 1'b1;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule