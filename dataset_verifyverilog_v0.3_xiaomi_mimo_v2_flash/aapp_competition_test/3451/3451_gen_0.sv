module make_impossible(
    input clk,
    input rst_n,
    input start,
    input [7:0] seq_0, seq_1, seq_2, seq_3,
    input [7:0] seq_4, seq_5, seq_6, seq_7,
    input [3:0] k,
    input signed [15:0] cost_0, cost_1, cost_2, cost_3,
    input signed [15:0] cost_4, cost_5, cost_6, cost_7,
    output reg signed [15:0] min_cost,
    output reg success,
    output reg done
);

    // State declarations
    localparam [2:0] S_IDLE       = 3'd0;
    localparam [2:0] S_PREPARE    = 3'd1;
    localparam [2:0] S_ENUMERATE  = 3'd2;
    localparam [2:0] S_COMPUTE    = 3'd3;
    localparam [2:0] S_CHECK      = 3'd4;
    localparam [2:0] S_DONE       = 3'd5;

    // Constants
    localparam [3:0] N = 4'd8;
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam signed [15:0] INF_COST = 16'sd30000;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    
    // Barry subset enumeration
    reg [7:0] barry_subset;      // N-bit mask
    reg [3:0] subset_idx;        // 0..255 for 2^N subsets
    reg signed [15:0] current_cost;
    reg signed [15:0] best_cost;
    reg current_success;
    
    // Working sequence storage
    reg [7:0] current_seq [0:7];
    reg [3:0] i, j;
    
    // DP state for Bruce's min flips
    reg [3:0] dp_i, dp_j;        // DP loop counters
    reg [7:0] dp_open [0:8];     // DP table row
    reg [7:0] dp_close [0:8];    // DP table row
    reg [7:0] temp_min;
    reg [3:0] balance;
    
    // Control flags
    reg compute_done;
    reg dp_initialized;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            success <= 1'b0;
            min_cost <= 16'sd0;
            cycle_count <= 8'd0;
            subset_idx <= 4'd0;
            barry_subset <= 8'd0;
            current_cost <= 16'sd0;
            best_cost <= INF_COST;
            current_success <= 1'b0;
            dp_i <= 4'd0;
            dp_j <= 4'd0;
            balance <= 4'd0;
            compute_done <= 1'b0;
            dp_initialized <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                current_seq[i] <= 8'd0;
                dp_open[i] <= 8'd0;
                dp_close[i] <= 8'd0;
            end
            dp_open[8] <= 8'd0;
            dp_close[8] <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    subset_idx <= 4'd0;
                    barry_subset <= 8'd0;
                    best_cost <= INF_COST;
                    current_success <= 1'b0;
                    if (start) begin
                        state <= S_PREPARE;
                    end
                end
                
                S_PREPARE: begin
                    // Initialize current_seq from inputs
                    current_seq[0] <= seq_0;
                    current_seq[1] <= seq_1;
                    current_seq[2] <= seq_2;
                    current_seq[3] <= seq_3;
                    current_seq[4] <= seq_4;
                    current_seq[5] <= seq_5;
                    current_seq[6] <= seq_6;
                    current_seq[7] <= seq_7;
                    state <= S_ENUMERATE;
                    subset_idx <= 4'd0;
                    barry_subset <= 8'd0;
                end
                
                S_ENUMERATE: begin
                    // Apply Barry's flip subset to current_seq
                    for (i = 0; i < 8; i = i + 1) begin
                        if (barry_subset[i]) begin
                            current_seq[i] <= ~seq_i[i];
                        end else begin
                            current_seq[i] <= seq_i[i];
                        end
                    end
                    
                    // Calculate Barry's cost for this subset
                    current_cost <= 16'sd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (barry_subset[i]) begin
                            case (i)
                                0: current_cost <= current_cost + cost_0;
                                1: current_cost <= current_cost + cost_1;
                                2: current_cost <= current_cost + cost_2;
                                3: current_cost <= current_cost + cost_3;
                                4: current_cost <= current_cost + cost_4;
                                5: current_cost <= current_cost + cost_5;
                                6: current_cost <= current_cost + cost_6;
                                7: current_cost <= current_cost + cost_7;
                                default: current_cost <= current_cost;
                            endcase
                        end
                    end
                    
                    compute_done <= 1'b0;
                    dp_initialized <= 1'b0;
                    dp_i <= 4'd1;
                    dp_j <= 4'd0;
                    state <= S_COMPUTE;
                end
                
                S_COMPUTE: begin
                    // DP initialization
                    if (!dp_initialized) begin
                        // Initialize base cases
                        for (j = 0; j <= 8; j = j + 1) begin
                            dp_open[j] <= 8'd0;
                            dp_close[j] <= 8'd0;
                        end
                        dp_initialized <= 1'b1;
                        dp_i <= 4'd1;
                        dp_j <= 4'd0;
                    end else begin
                        // DP computation: dp[i][j] = min flips to make balance j after i chars
                        if (dp_i <= 8) begin
                            if (dp_j <= 8) begin
                                // Read current character
                                if (dp_i >= 1) begin
                                    reg [7:0] char;
                                    case (dp_i - 1)
                                        0: char = current_seq[0];
                                        1: char = current_seq[1];
                                        2: char = current_seq[2];
                                        3: char = current_seq[3];
                                        4: char = current_seq[4];
                                        5: char = current_seq[5];
                                        6: char = current_seq[6];
                                        7: char = current_seq[7];
                                        default: char = 8'd0;
                                    endcase
                                    
                                    if (char == 8'd0) begin // '('
                                        // State remains valid: (i-1, j-1) -> (i, j)
                                        if (j > 0 && dp_j == j) begin
                                            if (dp_j <= 8) begin
                                                if (dp_open[dp_j] > dp_close[dp_j - 1]) begin
                                                    dp_open[dp_j] <= dp_close[dp_j - 1];
                                                end
                                            end
                                        end
                                    end else begin // ')'
                                        // State valid: (i-1, j+1) -> (i, j)
                                        if (j < 8 && dp_j == j) begin
                                            if (dp_j <= 8) begin
                                                if (dp_close[dp_j] > dp_open[dp_j + 1]) begin
                                                    dp_close[dp_j] <= dp_open[dp_j + 1];
                                                end
                                            end
                                        end
                                    end
                                end
                                dp_j <= dp_j + 4'd1;
                            end else begin
                                dp_j <= 4'd0;
                                dp_i <= dp_i + 4'd1;
                            end
                        end else begin
                            compute_done <= 1'b1;
                            state <= S_CHECK;
                        end
                    end
                end
                
                S_CHECK: begin
                    // Check if result is valid (dp[N][0] > k)
                    // Note: dp[8][0] represents balance 0 after 8 characters
                    // dp_close[0] stores min flips for balance 0
                    if (dp_close[0] > k) begin
                        // Barry can make it impossible
                        if (current_cost < best_cost) begin
                            best_cost <= current_cost;
                        end
                        current_success <= 1'b1;
                    end
                    
                    // Move to next subset
                    if (subset_idx < 255) begin
                        subset_idx <= subset_idx + 4'd1;
                        barry_subset <= barry_subset + 8'd1;
                        state <= S_ENUMERATE;
                    end else begin
                        // All subsets checked
                        state <= S_DONE;
                    end
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    success <= current_success;
                    min_cost <= best_cost;
                    if (cycle_count > MAX_CYCLES || start) begin
                        state <= S_IDLE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
            
            // Safety timeout
            if (cycle_count > MAX_CYCLES && state != S_DONE && state != S_IDLE) begin
                state <= S_DONE;
                done <= 1'b1;
                success <= 1'b0;
                min_cost <= INF_COST;
            end
        end
    end
    
    // Helper for seq access
    reg [7:0] seq_i;
    always @(*) begin
        case (i)
            0: seq_i = seq_0;
            1: seq_i = seq_1;
            2: seq_i = seq_2;
            3: seq_i = seq_3;
            4: seq_i = seq_4;
            5: seq_i = seq_5;
            6: seq_i = seq_6;
            7: seq_i = seq_7;
            default: seq_i = 8'd0;
        endcase
    end

endmodule