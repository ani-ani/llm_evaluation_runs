module color_painting_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a_i [0:15],
    input wire [15:0] b_i [0:15],
    input wire [3:0] C,
    input wire [6:0] Q,
    input wire update_en,
    input wire [3:0] update_idx,
    input wire [15:0] new_a,
    input wire [15:0] new_b,
    output reg [15:0] result,
    output reg done
);

    localparam [15:0] MOD = 16'd10007;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UPDATE_CLIENT = 3'd1;
    localparam [2:0] RESET_DP = 3'd2;
    localparam [2:0] COMPUTE_DP = 3'd3;
    localparam [2:0] CALCULATE_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    reg [2:0] state, next_state;
    reg [3:0] client_idx;
    reg [3:0] dp_idx;
    reg [15:0] dp_reg [0:15];
    reg [15:0] next_dp [0:15];
    reg [15:0] temp_a [0:15];
    reg [15:0] temp_b [0:15];
    reg [7:0] cycle_count;
    reg [15:0] result_acc;
    
    integer i;
    
    // Combinational signals
    wire [15:0] ways_client;
    assign ways_client = (temp_a[client_idx] + temp_b[client_idx]) % MOD;
    
    wire [15:0] mult_a;
    wire [15:0] mult_b;
    assign mult_a = dp_reg[dp_idx];
    assign mult_b = ways_client;
    
    wire [31:0] mult_result;
    assign mult_result = mult_a * mult_b;
    
    wire [15:0] new_dp_val;
    assign new_dp_val = (mult_result + dp_reg[dp_idx - 1]) % MOD;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            client_idx <= 4'd0;
            dp_idx <= 4'd0;
            cycle_count <= 8'd0;
            result_acc <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                dp_reg[i] <= 16'd0;
                next_dp[i] <= 16'd0;
                temp_a[i] <= 16'd0;
                temp_b[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_count <= 8'd0;
                    result_acc <= 16'd0;
                    // Initialize temp arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_a[i] <= a_i[i] % MOD;
                        temp_b[i] <= b_i[i] % MOD;
                    end
                end
                
                UPDATE_CLIENT: begin
                    // Only update the specific index
                    temp_a[update_idx] <= new_a % MOD;
                    temp_b[update_idx] <= new_b % MOD;
                    client_idx <= 4'd0;
                    dp_idx <= 4'd0;
                    cycle_count <= 8'd0;
                end
                
                RESET_DP: begin
                    // Reset dp array
                    dp_reg[0] <= 16'd1;
                    for (i = 1; i < 16; i = i + 1) begin
                        dp_reg[i] <= 16'd0;
                    end
                    client_idx <= 4'd0;
                    dp_idx <= 4'd0;
                    cycle_count <= 8'd0;
                end
                
                COMPUTE_DP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update dp array for current client
                    // dp[k] = dp[k] * ways + dp[k-1]
                    // Process backwards to avoid overwriting
                    if (client_idx == 4'd0) begin
                        dp_reg[0] <= 16'd1;
                        dp_reg[1] <= ways_client;
                        client_idx <= client_idx + 4'd1;
                    end else begin
                        // Copy next_dp to dp_reg for next iteration
                        for (i = 0; i < 16; i = i + 1) begin
                            dp_reg[i] <= next_dp[i];
                        end
                        client_idx <= client_idx + 4'd1;
                    end
                end
                
                CALCULATE_RESULT: begin
                    // Sum dp[k] for k >= C
                    if (dp_idx < C) begin
                        dp_idx <= dp_idx + 4'd1;
                    end else begin
                        result_acc <= (result_acc + dp_reg[dp_idx]) % MOD;
                        dp_idx <= dp_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= result_acc;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (update_en) next_state = UPDATE_CLIENT;
                else if (start) next_state = RESET_DP;
                else next_state = IDLE;
            end
            
            UPDATE_CLIENT: next_state = RESET_DP;
            
            RESET_DP: next_state = COMPUTE_DP;
            
            COMPUTE_DP: begin
                // Process all clients (N=16)
                if (client_idx >= 4'd15 && dp_idx >= 4'd0) begin
                    // Need one more cycle to write final results
                    if (cycle_count >= 8'd32) begin
                        next_state = CALCULATE_RESULT;
                    end else begin
                        next_state = COMPUTE_DP;
                    end
                end else begin
                    next_state = COMPUTE_DP;
                end
            end
            
            CALCULATE_RESULT: begin
                if (dp_idx >= 4'd15) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALCULATE_RESULT;
                end
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
    
    // DP update logic
    always @(*) begin
        // Initialize next_dp with current values
        for (i = 0; i < 16; i = i + 1) begin
            next_dp[i] = dp_reg[i];
        end
        
        // Process all dp indices for current client
        // dp[k] = dp[k] * ways + dp[k-1]
        // Process backwards
        for (i = 15; i > 0; i = i - 1) begin
            if (i == 15) begin
                next_dp[i] = (dp_reg[i] * ways_client) % MOD;
            end else begin
                next_dp[i] = (dp_reg[i] * ways_client + dp_reg[i - 1]) % MOD;
            end
        end
        next_dp[0] = dp_reg[0];
    end
    
endmodule