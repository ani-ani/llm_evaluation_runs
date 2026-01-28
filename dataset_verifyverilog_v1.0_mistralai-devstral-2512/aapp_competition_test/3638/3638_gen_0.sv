module SequenceProbabilityCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] n,
    input wire [3:0] len,
    input wire [29:0] seq_0,
    input wire [29:0] seq_1,
    input wire [29:0] seq_2,
    input wire [29:0] seq_3,
    input wire [29:0] seq_4,
    input wire [29:0] seq_5,
    input wire [29:0] seq_6,
    input wire [29:0] seq_7,
    input wire [29:0] seq_8,
    input wire [29:0] seq_9,
    output reg [3:0] result_idx,
    output reg valid,
    output reg done
);

    // Constants
    localparam [31:0] ONE_THIRD = 32'd21845;  // 1/3 in Q16.16
    localparam [31:0] ONE = 32'd65536;        // 1.0 in Q16.16

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_SEQ = 4'd1;
    localparam [3:0] CALC_PROB = 4'd2;
    localparam [3:0] SORT = 4'd3;
    localparam [3:0] OUTPUT = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;

    // Sequence storage
    reg [29:0] sequences [0:9];
    reg [3:0] current_seq_idx;
    reg [3:0] num_sequences;

    // Probability calculation
    reg [31:0] prob_L;  // (1/3)^L in Q16.16
    reg [31:0] prob_survival;  // 1 - prob_L
    reg [31:0] prob_result;  // Final probability
    reg [19:0] exponent;  // n - L + 1

    // Sorting
    reg [31:0] probabilities [0:9];
    reg [3:0] sorted_indices [0:9];
    reg [3:0] i, j;
    reg [31:0] temp_prob;
    reg [3:0] temp_idx;

    // Output control
    reg [3:0] output_idx;

    // Cycle counter for safety
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4095;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_seq_idx <= 4'd0;
            num_sequences <= 4'd0;
            prob_L <= 32'd0;
            prob_survival <= 32'd0;
            prob_result <= 32'd0;
            exponent <= 20'd0;
            result_idx <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            output_idx <= 4'd0;
            cycle_count <= 12'd0;

            // Initialize sequences and probabilities
            integer k;
            for (k = 0; k < 10; k = k + 1) begin
                sequences[k] <= 30'd0;
                probabilities[k] <= 32'd0;
                sorted_indices[k] <= k;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 12'd1;

            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        // Count number of sequences
                        num_sequences <= 4'd0;
                        if (seq_0 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_1 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_2 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_3 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_4 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_5 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_6 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_7 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_8 != 0) num_sequences <= num_sequences + 4'd1;
                        if (seq_9 != 0) num_sequences <= num_sequences + 4'd1;

                        current_seq_idx <= 4'd0;
                        next_state <= LOAD_SEQ;
                    end
                end

                LOAD_SEQ: begin
                    // Load sequences
                    sequences[0] <= seq_0;
                    sequences[1] <= seq_1;
                    sequences[2] <= seq_2;
                    sequences[3] <= seq_3;
                    sequences[4] <= seq_4;
                    sequences[5] <= seq_5;
                    sequences[6] <= seq_6;
                    sequences[7] <= seq_7;
                    sequences[8] <= seq_8;
                    sequences[9] <= seq_9;

                    // Initialize for probability calculation
                    prob_L <= ONE;  // Start with 1.0
                    exponent <= n - len + 20'd1;
                    next_state <= CALC_PROB;
                end

                CALC_PROB: begin
                    // Calculate prob_L = (1/3)^L
                    if (prob_L == 32'd0) begin
                        prob_L <= ONE;
                    end

                    // Multiply by 1/3, L times
                    if (len > 0) begin
                        prob_L <= (prob_L * ONE_THIRD) >>> 16;  // Q16.16 multiply
                        len <= len - 4'd1;
                    end else begin
                        // Calculate prob_survival = 1 - prob_L
                        prob_survival <= ONE - prob_L;

                        // Calculate prob_result = 1 - (prob_survival)^exponent
                        // Using iterative multiplication
                        prob_result <= ONE;
                        if (exponent > 0) begin
                            // Initialize for exponentiation
                            prob_result <= prob_survival;
                            exponent <= exponent - 20'd1;
                        end else begin
                            // Store result
                            probabilities[current_seq_idx] <= prob_result;
                            current_seq_idx <= current_seq_idx + 4'd1;

                            if (current_seq_idx < num_sequences) begin
                                // Reset for next sequence
                                prob_L <= ONE;
                                len <= {4{1'b0}};  // Reset len (will be reloaded)
                                next_state <= CALC_PROB;
                            end else begin
                                // All probabilities calculated, move to sort
                                next_state <= SORT;
                            end
                        end
                    end
                end

                SORT: begin
                    // Bubble sort for up to 10 elements
                    if (i < 9) begin
                        if (j < 9 - i) begin
                            if (probabilities[j] < probabilities[j + 1]) begin
                                // Swap probabilities
                                temp_prob <= probabilities[j];
                                probabilities[j] <= probabilities[j + 1];
                                probabilities[j + 1] <= temp_prob;

                                // Swap indices
                                temp_idx <= sorted_indices[j];
                                sorted_indices[j] <= sorted_indices[j + 1];
                                sorted_indices[j + 1] <= temp_idx;
                            end
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end
                    end else begin
                        // Sorting complete
                        output_idx <= 4'd0;
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    valid <= 1'b1;
                    result_idx <= sorted_indices[output_idx];

                    if (output_idx == num_sequences - 4'd1) begin
                        done <= 1'b1;
                        next_state <= DONE_STATE;
                    end else begin
                        output_idx <= output_idx + 4'd1;
                    end
                end

                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Safety check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = IDLE;
            LOAD_SEQ: next_state = LOAD_SEQ;
            CALC_PROB: next_state = CALC_PROB;
            SORT: next_state = SORT;
            OUTPUT: next_state = OUTPUT;
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

endmodule