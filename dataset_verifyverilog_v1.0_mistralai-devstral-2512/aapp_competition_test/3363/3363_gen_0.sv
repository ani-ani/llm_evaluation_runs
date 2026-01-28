module calorie_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] m,
    input [7:0] calories_0,
    input [7:0] calories_1,
    input [7:0] calories_2,
    input [7:0] calories_3,
    input [7:0] calories_4,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // DP table: [hour][streak][skip_count] -> max_calories
    reg [15:0] dp [0:4];
    reg [15:0] dp_next [0:4];
    
    // Current rate tracking
    reg [15:0] current_rate;
    reg [15:0] next_rate;
    
    // Streak and skip tracking
    reg [1:0] streak;
    reg [0:0] skip_count;
    
    // Calories array
    reg [7:0] calories [0:4];
    
    // Initialize calories array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calories[0] <= 8'd0;
            calories[1] <= 8'd0;
            calories[2] <= 8'd0;
            calories[3] <= 8'd0;
            calories[4] <= 8'd0;
        end else begin
            calories[0] <= calories_0;
            calories[1] <= calories_1;
            calories[2] <= calories_2;
            calories[3] <= calories_3;
            calories[4] <= calories_4;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize DP table
            dp[0] <= 16'd0;
            dp[1] <= 16'd0;
            dp[2] <= 16'd0;
            dp[3] <= 16'd0;
            dp[4] <= 16'd0;
            
            dp_next[0] <= 16'd0;
            dp_next[1] <= 16'd0;
            dp_next[2] <= 16'd0;
            dp_next[3] <= 16'd0;
            dp_next[4] <= 16'd0;
            
            current_rate <= 16'd0;
            next_rate <= 16'd0;
            streak <= 2'd0;
            skip_count <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Initialize for hour 0
                        current_rate <= m;
                        streak <= 2'd0;
                        skip_count <= 1'b0;
                        
                        // Initialize DP table for hour 0
                        dp[0] <= 16'd0; // Option: skip hour 0
                        dp[1] <= calories[0]; // Option: eat hour 0
                        dp[2] <= 16'd0;
                        dp[3] <= 16'd0;
                        dp[4] <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next rates and DP values
                    integer i;
                    for (i = 0; i < 5; i = i + 1) begin
                        // Current state: dp[i] represents max calories up to hour i
                        // For each hour, we have two options: eat or skip
                        
                        // Option 1: Eat at current hour
                        // Calculate calories for this hour
                        reg [15:0] eat_calories;
                        if (calories[i] < current_rate) begin
                            eat_calories = calories[i];
                        end else begin
                            eat_calories = current_rate;
                        end
                        
                        // Update streak and skip_count for eat option
                        reg [1:0] new_streak_eat;
                        reg [0:0] new_skip_eat;
                        if (streak < 2'd2) begin
                            new_streak_eat = streak + 1'd1;
                        end else begin
                            new_streak_eat = 2'd0;
                        end
                        new_skip_eat = 1'b0;
                        
                        // Calculate next rate for eat option
                        reg [15:0] next_rate_eat;
                        if (new_streak_eat == 2'd1 || new_streak_eat == 2'd2) begin
                            next_rate_eat = (current_rate * 8'd171) >> 8;
                        end else begin
                            next_rate_eat = m;
                        end
                        
                        // Option 2: Skip current hour
                        reg [1:0] new_streak_skip;
                        reg [0:0] new_skip_skip;
                        if (skip_count == 1'b1) begin
                            new_streak_skip = 2'd0;
                            new_skip_skip = 1'b0;
                        end else begin
                            new_streak_skip = streak;
                            new_skip_skip = skip_count + 1'b1;
                        end
                        
                        // Calculate next rate for skip option
                        reg [15:0] next_rate_skip;
                        if (new_skip_skip == 1'b1 && streak == 2'd0) begin
                            next_rate_skip = m;
                        end else begin
                            next_rate_skip = current_rate;
                        end
                        
                        // Update DP table
                        if (i < 4) begin
                            // For eat option
                            if (dp_next[i+1] < dp[i] + eat_calories) begin
                                dp_next[i+1] = dp[i] + eat_calories;
                            end
                            
                            // For skip option
                            if (dp_next[i+1] < dp[i]) begin
                                dp_next[i+1] = dp[i];
                            end
                        end
                        
                        // Update current_rate for next iteration
                        current_rate = next_rate;
                    end
                    
                    // Copy dp_next to dp for next cycle
                    dp[0] <= dp_next[0];
                    dp[1] <= dp_next[1];
                    dp[2] <= dp_next[2];
                    dp[3] <= dp_next[3];
                    dp[4] <= dp_next[4];
                    
                    // Check if computation is complete
                    if (cycle_count >= MAX_CYCLES || (dp[4] > 16'd0 && cycle_count > 8'd1)) begin
                        state <= FINISH;
                        result <= dp[4];
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule