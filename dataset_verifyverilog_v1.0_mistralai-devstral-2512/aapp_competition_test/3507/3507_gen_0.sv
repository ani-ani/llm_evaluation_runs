module wine_arrangements(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] R_in,
    input wire [15:0] W_in,
    input wire [7:0] d_in,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_R = 6'd32;
    localparam [5:0] MAX_W = 6'd32;
    localparam [5:0] MAX_D = 6'd32;

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [5:0] r, w, k;
    reg [1:0] last;
    reg [5:0] R_scaled, W_scaled, d_scaled;
    reg [5:0] r_max, w_max;
    reg [31:0] dp [0:31][0:31][0:1];
    reg [31:0] temp_val;
    reg [31:0] add_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize DP array
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r <= 6'd0;
            w <= 6'd0;
            k <= 6'd0;
            last <= 2'd0;
            R_scaled <= 6'd0;
            W_scaled <= 6'd0;
            d_scaled <= 6'd0;
            r_max <= 6'd0;
            w_max <= 6'd0;
            result <= 32'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 8'd0;
            
            // Initialize DP array
            for (i = 0; i < 32; i = i + 1) begin
                for (j = 0; j < 32; j = j + 1) begin
                    dp[i][j][0] <= 32'd0;
                    dp[i][j][1] <= 32'd0;
                end
            end
            dp[0][0][0] <= 32'd1;
            dp[0][0][1] <= 32'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Scale inputs
                        R_scaled <= (R_in > MAX_R) ? MAX_R : R_in;
                        W_scaled <= (W_in > MAX_W) ? MAX_W : W_in;
                        d_scaled <= (d_in > MAX_D) ? MAX_D : d_in;
                        r_max <= R_scaled;
                        w_max <= W_scaled;
                        
                        // Reset counters
                        r <= 6'd0;
                        w <= 6'd0;
                        last <= 2'd0;
                        k <= 6'd0;
                        
                        // Initialize DP array
                        for (i = 0; i < 32; i = i + 1) begin
                            for (j = 0; j < 32; j = j + 1) begin
                                dp[i][j][0] <= 32'd0;
                                dp[i][j][1] <= 32'd0;
                            end
                        end
                        dp[0][0][0] <= 32'd1;
                        dp[0][0][1] <= 32'd1;
                        
                        state <= COMPUTE;
                        ready <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Main computation loop
                    if (r <= r_max && w <= w_max) begin
                        if (last == 2'd0) begin
                            // Last pile was white, add red pile
                            if (k < d_scaled && (r + k + 1) <= r_max) begin
                                k <= k + 6'd1;
                            end else begin
                                // Process current state
                                if (dp[r][w][0] > 32'd0) begin
                                    temp_val <= dp[r][w][0];
                                    for (k = 6'd1; k <= d_scaled; k = k + 6'd1) begin
                                        if ((r + k) <= r_max) begin
                                            add_result <= dp[r + k][w][1] + temp_val;
                                            if (add_result >= MOD) begin
                                                dp[r + k][w][1] <= add_result - MOD;
                                            end else begin
                                                dp[r + k][w][1] <= add_result;
                                            end
                                        end
                                    end
                                end
                                k <= 6'd0;
                                
                                // Move to next state
                                if (w < w_max) begin
                                    w <= w + 6'd1;
                                end else begin
                                    w <= 6'd0;
                                    if (r < r_max) begin
                                        r <= r + 6'd1;
                                    end else begin
                                        r <= 6'd0;
                                        last <= 2'd1;
                                    end
                                end
                            end
                        end else begin
                            // Last pile was red, add white pile
                            if (k < w_max && (w + k + 1) <= w_max) begin
                                k <= k + 6'd1;
                            end else begin
                                // Process current state
                                if (dp[r][w][1] > 32'd0) begin
                                    temp_val <= dp[r][w][1];
                                    for (k = 6'd1; k <= (w_max - w); k = k + 6'd1) begin
                                        if ((w + k) <= w_max) begin
                                            add_result <= dp[r][w + k][0] + temp_val;
                                            if (add_result >= MOD) begin
                                                dp[r][w + k][0] <= add_result - MOD;
                                            end else begin
                                                dp[r][w + k][0] <= add_result;
                                            end
                                        end
                                    end
                                end
                                k <= 6'd0;
                                
                                // Move to next state
                                if (w < w_max) begin
                                    w <= w + 6'd1;
                                end else begin
                                    w <= 6'd0;
                                    if (r < r_max) begin
                                        r <= r + 6'd1;
                                    end else begin
                                        r <= 6'd0;
                                        last <= 2'd0;
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    // Compute final result
                    add_result <= dp[r_max][w_max][0] + dp[r_max][w_max][1];
                    if (add_result >= MOD) begin
                        result <= add_result - MOD;
                    end else begin
                        result <= add_result;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule