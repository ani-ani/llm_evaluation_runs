module min_insertions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] N,
    input wire [3:0] K,
    output reg [7:0] result,
    output reg done
);

    // DP array: dp[l][r][k] for l,r in [0,7], k in [0,4]
    reg [7:0] dp [0:7][0:7][0:4];
    
    // State definitions
    localparam [4:0] IDLE       = 5'd0;
    localparam [4:0] INIT       = 5'd1;
    localparam [4:0] LOOP_LEN   = 5'd2;
    localparam [4:0] LOOP_L     = 5'd3;
    localparam [4:0] COMPUTE    = 5'd4;
    localparam [4:0] LOOP_I     = 5'd5;
    localparam [4:0] UPDATE     = 5'd6;
    localparam [4:0] NEXT       = 5'd7;
    localparam [4:0] FINISH     = 5'd8;
    
    reg [4:0] state, next_state;
    
    // Loop counters and temporaries
    reg [3:0] len, l, r, k, i;
    reg [7:0] cost1, cost2, temp;
    reg [7:0] seg1_val, seg2_val;
    
    // Helper wires for segment computation
    wire seg1_valid;
    wire [7:0] seg1_wire;
    wire seg2_valid;
    wire [7:0] seg2_wire;
    
    assign seg1_valid = (l + 16'd1 <= i - 16'd1);
    assign seg1_wire = seg1_valid ? dp[l + 4'd1][i - 4'd1][4'd0] : 8'd0;
    
    assign seg2_valid = (i + 4'd1 <= r);
    assign seg2_wire = (k + 4'd1 >= K) ? (seg2_valid ? dp[i + 4'd1][r][4'd0] : 8'd0) : dp[i][r][k + 4'd1];
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main FSM and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            result <= 8'd0;
            len <= 4'd1;
            l <= 4'd0;
            k <= 4'd0;
            i <= 4'd0;
            cost1 <= 8'd0;
            cost2 <= 8'd0;
            temp <= 8'd0;
            seg1_val <= 8'd0;
            seg2_val <= 8'd0;
            
            // Reset DP array
            for (integer a = 0; a < 8; a = a + 1) begin
                for (integer b = 0; b < 8; b = b + 1) begin
                    for (integer c = 0; c < 5; c = c + 1) begin
                        dp[a][b][c] <= 8'd0;
                    end
                end
            end
        end else begin
            // State machine execution
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    len <= 4'd1;
                    l <= 4'd0;
                    k <= 4'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    if (l < N) begin
                        // Initialize dp[l][l][k] for all k
                        if (k < K) begin
                            if (k + 4'd1 >= K) begin
                                dp[l][l][k] <= 8'd0;
                            end else begin
                                dp[l][l][k] <= K - (k + 4'd1);
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            l <= l + 4'd1;
                        end
                    end else begin
                        l <= 4'd0;
                        len <= 4'd2;
                        next_state <= LOOP_LEN;
                    end
                end
                
                LOOP_LEN: begin
                    if (len > N) begin
                        next_state <= FINISH;
                    end else begin
                        l <= 4'd0;
                        next_state <= LOOP_L;
                    end
                end
                
                LOOP_L: begin
                    if (l >= N - len + 4'd1) begin
                        len <= len + 4'd1;
                        next_state <= LOOP_LEN;
                    end else begin
                        k <= 4'd0;
                        r <= l + len - 4'd1;
                        next_state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Compute cost1
                    if (k + 4'd1 >= K) begin
                        cost1 <= dp[l + 4'd1][r][4'd0];
                    end else begin
                        cost1 <= (K - (k + 4'd1)) + dp[l + 4'd1][r][4'd0];
                    end
                    
                    // Initialize cost2 and loop
                    cost2 <= 8'd255;
                    i <= l + 4'd1;
                    next_state <= LOOP_I;
                end
                
                LOOP_I: begin
                    if (i > r) begin
                        next_state <= UPDATE;
                    end else begin
                        if (arr[l] == arr[i]) begin
                            seg1_val <= seg1_wire;
                            seg2_val <= seg2_wire;
                            // Wait one cycle for pipeline
                            temp <= 8'd0;
                            next_state <= NEXT;
                        end else begin
                            i <= i + 4'd1;
                            next_state <= LOOP_I;
                        end
                    end
                end
                
                NEXT: begin
                    // Update cost2 if new value is smaller
                    if (seg1_val + seg2_val < cost2) begin
                        cost2 <= seg1_val + seg2_val;
                    end
                    i <= i + 4'd1;
                    next_state <= LOOP_I;
                end
                
                UPDATE: begin
                    // Store min of cost1 and cost2
                    if (cost1 < cost2) begin
                        dp[l][r][k] <= cost1;
                    end else begin
                        dp[l][r][k] <= cost2;
                    end
                    
                    // Move to next k
                    if (k + 4'd1 < K) begin
                        k <= k + 4'd1;
                        next_state <= COMPUTE;
                    end else begin
                        k <= 4'd0;
                        l <= l + 4'd1;
                        next_state <= LOOP_L;
                    end
                end
                
                FINISH: begin
                    result <= dp[4'd0][N - 4'd1][4'd0];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule