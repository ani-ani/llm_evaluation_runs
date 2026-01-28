module dice_optimal_reroll (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] K,
    input wire [7:0] T,
    input wire [2:0] initial_dice [23:0],
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LATCH     = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] DP_INIT   = 3'd3;
    localparam [2:0] DP_COMPUTE = 3'd4;
    localparam [2:0] EVAL      = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // Latched inputs
    reg [4:0] K_latched;
    reg [7:0] T_latched;
    reg [2:0] dice_latched [23:0];

    // Sorted dice (ascending order)
    reg [2:0] sorted_dice [23:0];

    // DP arrays for ways calculation
    reg [31:0] ways_prev [0:144];
    reg [31:0] ways_curr [0:144];

    // DP computation variables
    reg [7:0] d_count;
    reg [7:0] s_count;
    reg [7:0] v_count;

    // Evaluation variables
    reg [4:0] d_eval;
    reg [7:0] current_sum;
    reg [7:0] needed_sum;
    reg [31:0] max_ways;
    reg [4:0] best_d;

    // Sorting variables
    reg [4:0] i_sort;
    reg [4:0] j_sort;
    reg [2:0] temp_dice;

    // Cycle counter for timeout prevention
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP arrays
            integer k;
            for (k = 0; k < 145; k = k + 1) begin
                ways_prev[k] <= 32'd0;
                ways_curr[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LATCH;
                    end
                end

                LATCH: begin
                    // Latch inputs
                    K_latched <= K;
                    T_latched <= T;
                    integer k;
                    for (k = 0; k < 24; k = k + 1) begin
                        dice_latched[k] <= initial_dice[k];
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (i_sort < K_latched - 1) begin
                        if (j_sort < K_latched - i_sort - 1) begin
                            if (sorted_dice[j_sort] > sorted_dice[j_sort + 1]) begin
                                temp_dice <= sorted_dice[j_sort];
                                sorted_dice[j_sort] <= sorted_dice[j_sort + 1];
                                sorted_dice[j_sort + 1] <= temp_dice;
                            end
                            j_sort <= j_sort + 1;
                        end else begin
                            j_sort <= 0;
                            i_sort <= i_sort + 1;
                        end
                    end else begin
                        i_sort <= 0;
                        j_sort <= 0;
                        next_state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    // Initialize DP arrays
                    integer k;
                    for (k = 0; k < 145; k = k + 1) begin
                        ways_prev[k] <= 32'd0;
                        ways_curr[k] <= 32'd0;
                    end
                    ways_prev[0] <= 32'd1;
                    d_count <= 0;
                    s_count <= 0;
                    v_count <= 0;
                    next_state <= DP_COMPUTE;
                end

                DP_COMPUTE: begin
                    // DP computation for ways[d][s]
                    if (d_count < K_latched) begin
                        if (s_count < 145) begin
                            if (v_count < 6) begin
                                if (s_count >= v_count + 1) begin
                                    ways_curr[s_count] <= ways_curr[s_count] + ways_prev[s_count - (v_count + 1)];
                                end
                                v_count <= v_count + 1;
                            end else begin
                                v_count <= 0;
                                s_count <= s_count + 1;
                            end
                        end else begin
                            s_count <= 0;
                            // Copy ways_curr to ways_prev for next iteration
                            integer k;
                            for (k = 0; k < 145; k = k + 1) begin
                                ways_prev[k] <= ways_curr[k];
                                ways_curr[k] <= 32'd0;
                            end
                            d_count <= d_count + 1;
                        end
                    end else begin
                        d_count <= 0;
                        s_count <= 0;
                        v_count <= 0;
                        next_state <= EVAL;
                    end
                end

                EVAL: begin
                    // Evaluate each possible d
                    if (d_eval < K_latched + 1) begin
                        // Calculate current_sum of best (K_latched - d_eval) dice
                        if (d_eval == 0) begin
                            current_sum <= 0;
                            integer k;
                            for (k = 0; k < K_latched; k = k + 1) begin
                                current_sum <= current_sum + sorted_dice[k];
                            end
                        end else if (T_latched > current_sum) begin
                            // Keep largest dice
                            current_sum <= 0;
                            integer k;
                            for (k = K_latched - d_eval; k < K_latched; k = k + 1) begin
                                current_sum <= current_sum + sorted_dice[k];
                            end
                        end else begin
                            // Keep smallest dice
                            current_sum <= 0;
                            integer k;
                            for (k = 0; k < K_latched - d_eval; k = k + 1) begin
                                current_sum <= current_sum + sorted_dice[k];
                            end
                        end
                        
                        needed_sum <= T_latched - current_sum;
                        
                        // Check if needed_sum is within valid range
                        if (needed_sum >= d_eval && needed_sum <= 6 * d_eval) begin
                            if (ways_prev[needed_sum] > max_ways) begin
                                max_ways <= ways_prev[needed_sum];
                                best_d <= d_eval;
                            end else if (ways_prev[needed_sum] == max_ways && d_eval < best_d) begin
                                best_d <= d_eval;
                            end
                        end
                        
                        d_eval <= d_eval + 1;
                    end else begin
                        d_eval <= 0;
                        result <= best_d;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            
            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 0;
                next_state <= IDLE;
            end
        end
    end

    // Initialize sorted_dice from latched inputs
    always @(posedge clk) begin
        if (state == LATCH) begin
            integer k;
            for (k = 0; k < 24; k = k + 1) begin
                sorted_dice[k] <= dice_latched[k];
            end
        end
    end

    // Initialize evaluation variables
    always @(posedge clk) begin
        if (state == DP_COMPUTE && d_count == K_latched) begin
            max_ways <= 32'd0;
            best_d <= 5'd0;
        end
    end

endmodule