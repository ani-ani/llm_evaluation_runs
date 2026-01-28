module max_diversity(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] partner_frag [0:15],
    input wire [15:0] partner_step [0:15],
    input wire [15:0] partner_awake_frag [0:15],
    input wire [15:0] partner_awake_step [0:15],
    input wire [3:0] n,
    input wire [2:0] k,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EXPAND = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DP = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5120;

    // Expanded states (max 32)
    reg [4:0] num_states;
    reg [15:0] state_frag [0:31];
    reg [15:0] state_step [0:31];
    reg [2:0] state_cost [0:31];

    // DP table (32 states x 5 costs)
    reg [4:0] dp [0:31][0:4];

    // Internal counters
    reg [4:0] i, j, c;
    reg [4:0] max_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            num_states <= 5'd0;
            
            // Initialize arrays
            for (i = 0; i < 32; i = i + 1) begin
                state_frag[i] <= 16'd0;
                state_step[i] <= 16'd0;
                state_cost[i] <= 3'd0;
                for (c = 0; c < 5; c = c + 1) begin
                    dp[i][c] <= 5'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= EXPAND;
                    end
                end

                EXPAND: begin
                    // Expand partners into states
                    num_states <= 5'd0;
                    for (i = 0; i < n; i = i + 1) begin
                        // Unawakened state
                        state_frag[num_states] <= partner_frag[i];
                        state_step[num_states] <= partner_step[i];
                        state_cost[num_states] <= 3'd0;
                        num_states <= num_states + 5'd1;
                        
                        // Awakened state (if valid)
                        if (partner_awake_frag[i] != 16'd0 || partner_awake_step[i] != 16'd0) begin
                            state_frag[num_states] <= partner_awake_frag[i];
                            state_step[num_states] <= partner_awake_step[i];
                            state_cost[num_states] <= 3'd1;
                            num_states <= num_states + 5'd1;
                        end
                    end
                    state <= SORT;
                end

                SORT: begin
                    // Bubble sort by frag
                    for (i = 0; i < num_states - 5'd1; i = i + 1) begin
                        for (j = 0; j < num_states - i - 5'd1; j = j + 1) begin
                            if (state_frag[j] > state_frag[j + 5'd1]) begin
                                // Swap frag
                                state_frag[j] <= state_frag[j + 5'd1];
                                state_frag[j + 5'd1] <= state_frag[j];
                                
                                // Swap step
                                state_step[j] <= state_step[j + 5'd1];
                                state_step[j + 5'd1] <= state_step[j];
                                
                                // Swap cost
                                state_cost[j] <= state_cost[j + 5'd1];
                                state_cost[j + 5'd1] <= state_cost[j];
                            end
                        end
                    end
                    state <= DP;
                end

                DP: begin
                    // Initialize DP table
                    for (i = 0; i < num_states; i = i + 1) begin
                        for (c = 0; c < 5; c = c + 1) begin
                            dp[i][c] <= 5'd0;
                        end
                        dp[i][state_cost[i]] <= 5'd1;
                    end
                    
                    // Compute DP
                    for (i = 0; i < num_states; i = i + 1) begin
                        for (j = 0; j < i; j = j + 1) begin
                            if (state_frag[j] < state_frag[i] && state_step[j] < state_step[i]) begin
                                for (c = 0; c < 5; c = c + 1) begin
                                    if (c >= state_cost[i]) begin
                                        if (dp[j][c - state_cost[i]] + 5'd1 > dp[i][c]) begin
                                            dp[i][c] <= dp[j][c - state_cost[i]] + 5'd1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    // Find max result
                    max_result <= 5'd0;
                    for (i = 0; i < num_states; i = i + 1) begin
                        for (c = 0; c <= k; c = c + 1) begin
                            if (dp[i][c] > max_result) begin
                                max_result <= dp[i][c];
                            end
                        end
                    end
                    result <= max_result[3:0];
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 16'd1;
            end else begin
                cycle_count <= 16'd0;
                state <= IDLE;
            end
        end
    end
endmodule