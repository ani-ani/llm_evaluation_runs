module MaximalFactoring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_in [0:15],
    input wire [4:0] length_in,
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] MAIN_LOOP = 3'd3;
    localparam [2:0] COMPUTE_SPLIT = 3'd4;
    localparam [2:0] CHECK_REPETITION = 3'd5;
    localparam [2:0] UPDATE_DP = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] str [0:15];
    reg [4:0] n;
    reg [3:0] L, i, j, k, d;
    reg [4:0] min_val, temp_sum;
    reg [3:0] loop_counter;
    reg [4:0] dp [0:255];
    reg [3:0] r, p;
    reg [7:0] char1, char2;
    reg [3:0] remainder;
    reg [3:0] temp_L;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            n <= 5'd0;
            L <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            d <= 4'd0;
            min_val <= 5'd0;
            temp_sum <= 5'd0;
            loop_counter <= 4'd0;
            r <= 4'd0;
            p <= 4'd0;
            char1 <= 8'd0;
            char2 <= 8'd0;
            remainder <= 4'd0;
            temp_L <= 4'd0;
            
            // Initialize dp memory
            integer idx;
            for (idx = 0; idx < 256; idx = idx + 1) begin
                dp[idx] <= 5'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = INIT;
            end
            
            INIT: begin
                if (loop_counter == 4'd15) begin
                    next_state = MAIN_LOOP;
                end
            end
            
            MAIN_LOOP: begin
                if (L == n) begin
                    next_state = DONE_STATE;
                else if (i == (n - L)) begin
                    next_state = MAIN_LOOP;
                else begin
                    next_state = COMPUTE_SPLIT;
                end
            end
            
            COMPUTE_SPLIT: begin
                if (k == (j - 1)) begin
                    next_state = CHECK_REPETITION;
                end
            end
            
            CHECK_REPETITION: begin
                if (d == (L / 2)) begin
                    next_state = UPDATE_DP;
                end
            end
            
            UPDATE_DP: begin
                next_state = MAIN_LOOP;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                LOAD: begin
                    // Load string and length
                    integer idx;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        str[idx] <= string_in[idx];
                    end
                    n <= length_in;
                end
                
                INIT: begin
                    // Initialize dp for length 1
                    if (loop_counter < n) begin
                        dp[{loop_counter, loop_counter}] <= 5'd1;
                        loop_counter <= loop_counter + 4'd1;
                    end
                end
                
                MAIN_LOOP: begin
                    // Iterate L from 2 to n
                    if (L == 4'd0) begin
                        L <= 4'd2;
                        i <= 4'd0;
                        j <= L - 4'd1;
                    end else begin
                        if (i == (n - L)) begin
                            L <= L + 4'd1;
                            i <= 4'd0;
                            j <= L - 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            j <= i + L - 4'd1;
                        end
                    end
                    min_val <= 5'd32;
                end
                
                COMPUTE_SPLIT: begin
                    // Iterate k from i to j-1
                    if (k == 4'd0) begin
                        k <= i;
                    end else begin
                        k <= k + 4'd1;
                    end
                    
                    // Compute dp[i][k] + dp[k+1][j]
                    temp_sum <= dp[{i, k}] + dp[{k + 4'd1, j}];
                    
                    // Update min_val
                    if (temp_sum < min_val) begin
                        min_val <= temp_sum;
                    end
                end
                
                CHECK_REPETITION: begin
                    // Iterate d from 1 to L/2
                    if (d == 4'd0) begin
                        d <= 4'd1;
                        remainder <= L;
                    end else begin
                        // Check if L % d == 0
                        if (remainder >= d) begin
                            remainder <= remainder - d;
                        end
                        
                        if (remainder == 4'd0) begin
                            // Check periodicity
                            if (p == 4'd0) begin
                                p <= 4'd1;
                                r <= 4'd0;
                            end else begin
                                if (r == (d - 4'd1)) begin
                                    if (p == ((L / d) - 4'd1)) begin
                                        // All repetitions match
                                        temp_sum <= dp[{i, i + d - 4'd1}];
                                        if (temp_sum < min_val) begin
                                            min_val <= temp_sum;
                                        end
                                        d <= d + 4'd1;
                                        remainder <= L;
                                        p <= 4'd0;
                                    end else begin
                                        p <= p + 4'd1;
                                        r <= 4'd0;
                                    end
                                end else begin
                                    r <= r + 4'd1;
                                    char1 <= str[i + r];
                                    char2 <= str[i + r + d];
                                    if (char1 != char2) begin
                                        p <= (L / d);
                                    end
                                end
                            end
                        end else begin
                            d <= d + 4'd1;
                            remainder <= L;
                        end
                    end
                end
                
                UPDATE_DP: begin
                    // Store min_val into dp[{i,j}]
                    dp[{i, j}] <= min_val;
                end
                
                DONE_STATE: begin
                    // Set result and pulse done
                    result <= dp[{4'd0, n - 4'd1}];
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule