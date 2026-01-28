module printf_placement(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [7:0] r,
    input [7:0] p,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [9:0] current_n;
    reg [15:0] dp [0:1024];
    reg [9:0] i;
    reg [9:0] k;
    reg [15:0] min_time;
    reg [15:0] temp_time;
    reg [15:0] max_time;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd5000;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 10'd0;
            cycle_count <= 10'd0;
            
            // Initialize DP table
            for (i = 0; i < 1025; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_n <= n;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Base case: n=1
                    if (current_n == 10'd1) begin
                        result <= 16'd0;
                        state <= FINISH;
                    end
                    // Compute for n > 1
                    else if (current_n > 10'd1) begin
                        min_time <= 16'd32767;
                        
                        // Try all split positions k from 1 to current_n-1
                        for (k = 1; k < current_n; k = k + 1) begin
                            // Compute max(T(k), T(n-k))
                            if (dp[k] > dp[current_n - k])
                                max_time <= dp[k];
                            else
                                max_time <= dp[current_n - k];
                            
                            // Compute time for this split
                            temp_time <= p + r + max_time;
                            
                            // Update minimum time
                            if (temp_time < min_time)
                                min_time <= temp_time;
                        end
                        
                        // Store result for this n
                        dp[current_n] <= min_time;
                        result <= min_time;
                        state <= FINISH;
                    end
                    // If n=0 (invalid), finish immediately
                    else begin
                        result <= 16'd0;
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
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