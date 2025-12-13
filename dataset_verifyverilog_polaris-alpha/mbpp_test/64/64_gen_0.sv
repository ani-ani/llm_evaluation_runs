module sort_by_score(
    input              clk,
    input              start,
    input              rst_n,
    input       [3:0][7:0] scores,
    output reg  [3:0][7:0] sorted_scores,
    output reg  [3:0][1:0] sorted_indices,
    output reg         done
);

    // State encoding
    localparam IDLE    = 2'b00;
    localparam COMPARE = 2'b01;
    localparam SWAP    = 2'b10;
    localparam DONE    = 2'b11;

    reg [1:0] state, next_state;

    // Internal arrays for working scores and indices
    reg [7:0] score_reg [3:0];
    reg [1:0] index_reg [3:0];

    // Bubble sort control
    reg [2:0] pass_cnt;   // 0..3
    reg [1:0] cmp_idx;    // 0..2

    // Next values
    reg [2:0] next_pass_cnt;
    reg [1:0] next_cmp_idx;

    integer k;

    // Sequential logic: state, counters, arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            pass_cnt   <= 3'd0;
            cmp_idx    <= 2'd0;
            done       <= 1'b0;
            sorted_scores  <= '{default:8'd0};
            sorted_indices <= '{default:2'd0};
            for (k = 0; k < 4; k = k + 1) begin
                score_reg[k] <= 8'd0;
                index_reg[k] <= 2'd0;
            end
        end else begin
            state    <= next_state;
            pass_cnt <= next_pass_cnt;
            cmp_idx  <= next_cmp_idx;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Capture inputs and initialize indices
                        score_reg[0] <= scores[0];
                        score_reg[1] <= scores[1];
                        score_reg[2] <= scores[2];
                        score_reg[3] <= scores[3];
                        index_reg[0] <= 2'd0;
                        index_reg[1] <= 2'd1;
                        index_reg[2] <= 2'd2;
                        index_reg[3] <= 2'd3;
                    end
                    done <= 1'b0;
                end

                COMPARE: begin
                    // No array update here; swap (if needed) happens in SWAP
                    done <= 1'b0;
                end

                SWAP: begin
                    // Perform conditional swap between cmp_idx and cmp_idx+1
                    if (score_reg[cmp_idx] > score_reg[cmp_idx + 1]) begin
                        // Swap scores
                        {score_reg[cmp_idx], score_reg[cmp_idx + 1]} <= {score_reg[cmp_idx + 1], score_reg[cmp_idx]};
                        // Swap indices to track original positions
                        {index_reg[cmp_idx], index_reg[cmp_idx + 1]} <= {index_reg[cmp_idx + 1], index_reg[cmp_idx]};
                    end
                    done <= 1'b0;
                end

                DONE: begin
                    // Latch final sorted outputs
                    sorted_scores[0]  <= score_reg[0];
                    sorted_scores[1]  <= score_reg[1];
                    sorted_scores[2]  <= score_reg[2];
                    sorted_scores[3]  <= score_reg[3];

                    sorted_indices[0] <= index_reg[0];
                    sorted_indices[1] <= index_reg[1];
                    sorted_indices[2] <= index_reg[2];
                    sorted_indices[3] <= index_reg[3];

                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next-state and counter logic
    always @(*) begin
        next_state    = state;
        next_pass_cnt = pass_cnt;
        next_cmp_idx  = cmp_idx;

        case (state)
            IDLE: begin
                if (start) begin
                    next_pass_cnt = 3'd0;
                    next_cmp_idx  = 2'd0;
                    next_state    = COMPARE;
                end
            end

            COMPARE: begin
                // If all passes done, go to DONE
                if (pass_cnt == 3) begin
                    next_state = DONE;
                end else begin
                    // Go to SWAP for current cmp_idx
                    next_state = SWAP;
                end
            end

            SWAP: begin
                // Advance cmp_idx / pass_cnt after swap decision
                if (cmp_idx < 2) begin
                    // More comparisons in this pass
                    next_cmp_idx  = cmp_idx + 1;
                    next_state    = COMPARE;
                end else begin
                    // End of this pass, increment pass_cnt
                    next_cmp_idx  = 2'd0;
                    next_pass_cnt = pass_cnt + 1;
                    next_state    = COMPARE;
                end
            end

            DONE: begin
                // Wait for next start to restart sorting
                if (start) begin
                    next_pass_cnt = 3'd0;
                    next_cmp_idx  = 2'd0;
                    next_state    = COMPARE;
                end else begin
                    next_state = DONE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule