module vacation_dp(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] day_arr [0:99],
    input wire [6:0] n,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // FSM state
    reg [1:0] state;

    // Day counter
    reg [6:0] day_counter;

    // DP array (3 states)
    reg [7:0] dp [0:2];

    // Temporary variables for computation
    reg [7:0] min_val;
    reg [7:0] temp_val;

    // Infinity value
    localparam [7:0] INF = 8'd255;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_counter <= 7'd0;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            
            // Initialize DP array
            dp[0] <= 8'd0;
            dp[1] <= 8'd0;
            dp[2] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        busy <= 1'b1;
                    end
                end

                LOAD: begin
                    // Initialize DP array for day 0
                    dp[0] <= 8'd0;
                    dp[1] <= 8'd0;
                    dp[2] <= 8'd0;
                    day_counter <= 7'd0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    // Compute next DP values
                    // State 0: Rest (always possible)
                    min_val = dp[0];
                    if (dp[1] < min_val) min_val = dp[1];
                    if (dp[2] < min_val) min_val = dp[2];
                    temp_val = min_val + 8'd1;

                    // State 1: Contest (if available)
                    if (day_arr[day_counter][1]) begin
                        min_val = dp[0];
                        if (dp[2] < min_val) min_val = dp[2];
                        dp[1] = min_val;
                    end else begin
                        dp[1] = INF;
                    end

                    // State 2: Sport (if available)
                    if (day_arr[day_counter][2]) begin
                        min_val = dp[0];
                        if (dp[1] < min_val) min_val = dp[1];
                        dp[2] = min_val;
                    end else begin
                        dp[2] = INF;
                    end

                    // Update state 0
                    dp[0] = temp_val;

                    // Increment day counter
                    day_counter <= day_counter + 7'd1;

                    // Check if done
                    if (day_counter == n) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Compute final result
                    min_val = dp[0];
                    if (dp[1] < min_val) min_val = dp[1];
                    if (dp[2] < min_val) min_val = dp[2];
                    result <= min_val;
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule