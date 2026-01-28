module WORST_RANK_COMPUTER (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] my_scores [0:7],
    input wire [7:0] other_scores [0:15][0:7],
    input wire [3:0] num_participants,
    input wire [2:0] num_contests,
    output reg [4:0] worst_rank,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_SELF = 3'd1;
    localparam [2:0] CALC_OTHERS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [9:0] self_aggregate;
    reg [4:0] beat_count;
    reg [3:0] other_idx;
    reg [2:0] i, j, k; // Iteration indices
    
    // Temporary storage for scores and sorting
    reg [7:0] temp_scores [0:7];
    reg [7:0] temp_val;
    reg [9:0] current_aggregate;
    reg [9:0] temp_aggregate;
    
    // Control flags
    reg sorting_done;
    reg calc_done;
    reg [3:0] max_index;
    reg [2:0] swap_count;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CALC_SELF : IDLE;
            CALC_SELF: next_state = calc_done ? CALC_OTHERS : CALC_SELF;
            CALC_OTHERS: begin
                if (calc_done) begin
                    if (other_idx >= num_participants - 4'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = CALC_OTHERS;
                    end
                end else begin
                    next_state = CALC_OTHERS;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            worst_rank <= 5'd0;
            self_aggregate <= 10'd0;
            beat_count <= 5'd0;
            other_idx <= 4'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            calc_done <= 1'b0;
            sorting_done <= 1'b0;
            current_aggregate <= 10'd0;
            swap_count <= 3'd0;
            max_index <= 4'd0;
            // Initialize temp_scores
            temp_scores[0] <= 8'd0;
            temp_scores[1] <= 8'd0;
            temp_scores[2] <= 8'd0;
            temp_scores[3] <= 8'd0;
            temp_scores[4] <= 8'd0;
            temp_scores[5] <= 8'd0;
            temp_scores[6] <= 8'd0;
            temp_scores[7] <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset counters and flags
                        other_idx <= 4'd1;
                        beat_count <= 5'd0;
                        calc_done <= 1'b0;
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                        swap_count <= 3'd0;
                    end
                end

                CALC_SELF: begin
                    // Load data on first cycle of this state
                    if (i == 3'd0 && j == 3'd0) begin
                        // Load my_scores into temp_scores
                        temp_scores[0] <= my_scores[0];
                        temp_scores[1] <= my_scores[1];
                        temp_scores[2] <= my_scores[2];
                        temp_scores[3] <= my_scores[3];
                        temp_scores[4] <= my_scores[4];
                        temp_scores[5] <= my_scores[5];
                        temp_scores[6] <= my_scores[6];
                        temp_scores[7] <= my_scores[7];
                        sorting_done <= 1'b0;
                        current_aggregate <= 10'd0;
                        // Adjust loop limits based on num_contests
                        // We only care about valid scores, but to simplify logic we sort all 8
                        // Missing scores are 0 (assumed, or initialized as 0).
                    end else begin
                        // Bubble Sort Logic (Modified to find top 4 efficiently)
                        // We perform one swap per cycle
                        if (!sorting_done) begin
                            if (temp_scores[j] < temp_scores[j + 1]) begin
                                // Swap
                                temp_val <= temp_scores[j];
                                temp_scores[j] <= temp_scores[j + 1];
                                temp_scores[j + 1] <= temp_val;
                            end
                            
                            if (j >= 3'd6) begin
                                j <= 3'd0;
                                swap_count <= swap_count + 3'd1;
                                // If we've made 8 passes or no swaps in a pass (simplified to 8 passes for deterministic timing)
                                if (swap_count >= 3'd6) begin // 6 passes usually sufficient for top 4 of 8
                                    sorting_done <= 1'b1;
                                    // Reset for summation phase
                                    i <= 3'd0;
                                end
                            end else begin
                                j <= j + 3'd1;
                            end
                        end else begin
                            // Summation phase: Sum top 4 scores
                            if (i < 3'd4) begin
                                current_aggregate <= current_aggregate + temp_scores[i];
                                i <= i + 3'd1;
                            end else begin
                                self_aggregate <= current_aggregate;
                                calc_done <= 1'b1;
                            end
                        end
                    end
                end

                CALC_OTHERS: begin
                    if (i == 3'd0 && j == 3'd0 && k == 3'd0) begin
                        // Load specific participant's scores into temp_scores
                        // other_idx is the index in the 2D array (0 to 14)
                        temp_scores[0] <= other_scores[other_idx][0];
                        temp_scores[1] <= other_scores[other_idx][1];
                        temp_scores[2] <= other_scores[other_idx][2];
                        temp_scores[3] <= other_scores[other_idx][3];
                        temp_scores[4] <= other_scores[other_idx][4];
                        temp_scores[5] <= other_scores[other_idx][5];
                        temp_scores[6] <= other_scores[other_idx][6];
                        temp_scores[7] <= other_scores[other_idx][7];
                        sorting_done <= 1'b0;
                        current_aggregate <= 10'd0;
                    end else begin
                        if (!sorting_done) begin
                            // Bubble Sort
                            if (temp_scores[j] < temp_scores[j + 1]) begin
                                temp_val <= temp_scores[j];
                                temp_scores[j] <= temp_scores[j + 1];
                                temp_scores[j + 1] <= temp_val;
                            end
                            
                            if (j >= 3'd6) begin
                                j <= 3'd0;
                                swap_count <= swap_count + 3'd1;
                                if (swap_count >= 3'd6) begin
                                    sorting_done <= 1'b1;
                                    i <= 3'd0;
                                end
                            end else begin
                                j <= j + 3'd1;
                            end
                        end else begin
                            // Summation
                            if (i < 3'd4) begin
                                current_aggregate <= current_aggregate + temp_scores[i];
                                i <= i + 3'd1;
                            end else begin
                                // Comparison
                                temp_aggregate <= current_aggregate;
                                if (current_aggregate > self_aggregate) begin
                                    beat_count <= beat_count + 5'd1;
                                end
                                // Prepare for next participant or finish
                                other_idx <= other_idx + 4'd1;
                                calc_done <= 1'b1;
                            end
                        end
                    end
                end

                FINISH: begin
                    worst_rank <= 5'd1 + beat_count;
                    done <= 1'b1;
                end
            endcase
            
            // Clear calc_done flag when transitioning out of calculation states
            if (state != CALC_SELF && state != CALC_OTHERS) begin
                calc_done <= 1'b0;
            end
        end
    end

endmodule