module wine_arrangements (
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

// State declarations
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] LOAD_IN = 3'd1;
localparam [2:0] INIT_DP = 3'd2;
localparam [2:0] COMPUTE = 3'd3;
localparam [2:0] OUTPUT  = 3'd4;

// Internal registers
reg [2:0] state, next_state;
reg [5:0] r_cnt, w_cnt, k_cnt;
reg [1:0] last_cnt;
reg [5:0] R_max, W_max, d_max;
reg [31:0] current_val;
reg [31:0] dp_mem [0:63][0:63][0:1];  // 32x32x2 array
reg [5:0] i, j;

// Helper signals for timing
reg compute_stage;
reg [5:0] add_r, add_w;
reg [1:0] add_last;
reg [31:0] add_val;

// Initialize memory on reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) begin
            for (j = 0; j < 64; j = j + 1) begin
                dp_mem[i][j][0] <= 32'd0;
                dp_mem[i][j][1] <= 32'd0;
            end
        end
    end
end

// State machine and datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        ready <= 1'b1;
        r_cnt <= 6'd0;
        w_cnt <= 6'd0;
        k_cnt <= 6'd0;
        last_cnt <= 2'd0;
        R_max <= 6'd0;
        W_max <= 6'd0;
        d_max <= 6'd0;
        current_val <= 32'd0;
        compute_stage <= 1'b0;
        add_r <= 6'd0;
        add_w <= 6'd0;
        add_last <= 2'd0;
        add_val <= 32'd0;
    end else begin
        // Default outputs
        done <= 1'b0;
        
        case (state)
            IDLE: begin
                ready <= 1'b1;
                if (start) begin
                    ready <= 1'b0;
                    state <= LOAD_IN;
                end
            end
            
            LOAD_IN: begin
                // Clamp inputs to max 32
                R_max <= (R_in > 16'd32) ? 6'd32 : R_in[5:0];
                W_max <= (W_in > 16'd32) ? 6'd32 : W_in[5:0];
                d_max <= (d_in > 8'd32) ? 6'd32 : d_in[5:0];
                state <= INIT_DP;
                r_cnt <= 6'd0;
                w_cnt <= 6'd0;
            end
            
            INIT_DP: begin
                // Initialize dp_mem to 0, then set DP[0][0][0] = 1 and DP[0][0][1] = 1
                if (r_cnt == 6'd0 && w_cnt == 6'd0) begin
                    dp_mem[0][0][0] <= 32'd1;
                    dp_mem[0][0][1] <= 32'd1;
                end else begin
                    dp_mem[r_cnt][w_cnt][0] <= 32'd0;
                    dp_mem[r_cnt][w_cnt][1] <= 32'd0;
                end
                
                // Increment counters
                if (w_cnt < 6'd63) begin
                    w_cnt <= w_cnt + 6'd1;
                end else begin
                    w_cnt <= 6'd0;
                    if (r_cnt < 6'd63) begin
                        r_cnt <= r_cnt + 6'd1;
                    end else begin
                        r_cnt <= 6'd0;
                        w_cnt <= 6'd0;
                        last_cnt <= 2'd0;
                        compute_stage <= 1'b0;
                        state <= COMPUTE;
                    end
                end
            end
            
            COMPUTE: begin
                if (!compute_stage) begin
                    // Load current state value
                    current_val <= dp_mem[r_cnt][w_cnt][last_cnt];
                    compute_stage <= 1'b1;
                    k_cnt <= 6'd1;
                    
                    // Determine bounds for k
                    if (last_cnt == 2'd0) begin
                        // Last was white, add red pile
                        if (r_cnt < R_max) begin
                            // Valid to add red
                        end else begin
                            compute_stage <= 1'b0;
                            // Move to next state
                            if (last_cnt < 2'd1) begin
                                last_cnt <= last_cnt + 2'd1;
                            end else begin
                                last_cnt <= 2'd0;
                                if (w_cnt < W_max) begin
                                    w_cnt <= w_cnt + 6'd1;
                                end else begin
                                    w_cnt <= 6'd0;
                                    if (r_cnt < R_max) begin
                                        r_cnt <= r_cnt + 6'd1;
                                    end else begin
                                        // Done computing
                                        r_cnt <= R_max;
                                        w_cnt <= W_max;
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Last was red, add white pile
                        if (w_cnt < W_max) begin
                            // Valid to add white
                        end else begin
                            compute_stage <= 1'b0;
                            // Move to next state
                            if (last_cnt < 2'd1) begin
                                last_cnt <= last_cnt + 2'd1;
                            end else begin
                                last_cnt <= 2'd0;
                                if (w_cnt < W_max) begin
                                    w_cnt <= w_cnt + 6'd1;
                                end else begin
                                    w_cnt <= 6'd0;
                                    if (r_cnt < R_max) begin
                                        r_cnt <= r_cnt + 6'd1;
                                    end else begin
                                        r_cnt <= R_max;
                                        w_cnt <= W_max;
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end
                end else begin
                    // Perform addition and store
                    if (current_val != 32'd0) begin
                        // Determine where to add
                        if (last_cnt == 2'd0) begin
                            // Add red pile
                            if (k_cnt <= d_max && (r_cnt + k_cnt) <= R_max) begin
                                add_r <= r_cnt + k_cnt;
                                add_w <= w_cnt;
                                add_last <= 2'd1;
                                add_val <= dp_mem[r_cnt + k_cnt][w_cnt][1] + current_val;
                            end
                        end else begin
                            // Add white pile
                            if (k_cnt <= (W_max - w_cnt)) begin
                                add_r <= r_cnt;
                                add_w <= w_cnt + k_cnt;
                                add_last <= 2'd0;
                                add_val <= dp_mem[r_cnt][w_cnt + k_cnt][0] + current_val;
                            end
                        end
                    end
                    
                    // Store result (if valid)
                    if (current_val != 32'd0) begin
                        if (last_cnt == 2'd0) begin
                            if (k_cnt <= d_max && (r_cnt + k_cnt) <= R_max) begin
                                if (add_val >= MOD) begin
                                    dp_mem[add_r][add_w][add_last] <= add_val - MOD;
                                end else begin
                                    dp_mem[add_r][add_w][add_last] <= add_val;
                                end
                            end
                        end else begin
                            if (k_cnt <= (W_max - w_cnt)) begin
                                if (add_val >= MOD) begin
                                    dp_mem[add_r][add_w][add_last] <= add_val - MOD;
                                end else begin
                                    dp_mem[add_r][add_w][add_last] <= add_val;
                                end
                            end
                        end
                    end
                    
                    // Increment k
                    if (last_cnt == 2'd0) begin
                        if (k_cnt < d_max && (r_cnt + k_cnt) <= R_max) begin
                            k_cnt <= k_cnt + 6'd1;
                        end else begin
                            // Done with this k loop
                            compute_stage <= 1'b0;
                            // Move to next state
                            if (last_cnt < 2'd1) begin
                                last_cnt <= last_cnt + 2'd1;
                            end else begin
                                last_cnt <= 2'd0;
                                if (w_cnt < W_max) begin
                                    w_cnt <= w_cnt + 6'd1;
                                end else begin
                                    w_cnt <= 6'd0;
                                    if (r_cnt < R_max) begin
                                        r_cnt <= r_cnt + 6'd1;
                                    end else begin
                                        r_cnt <= R_max;
                                        w_cnt <= W_max;
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end else begin
                        if (k_cnt < (W_max - w_cnt)) begin
                            k_cnt <= k_cnt + 6'd1;
                        end else begin
                            // Done with this k loop
                            compute_stage <= 1'b0;
                            // Move to next state
                            if (last_cnt < 2'd1) begin
                                last_cnt <= last_cnt + 2'd1;
                            end else begin
                                last_cnt <= 2'd0;
                                if (w_cnt < W_max) begin
                                    w_cnt <= w_cnt + 6'd1;
                                end else begin
                                    w_cnt <= 6'd0;
                                    if (r_cnt < R_max) begin
                                        r_cnt <= r_cnt + 6'd1;
                                    end else begin
                                        r_cnt <= R_max;
                                        w_cnt <= W_max;
                                        state <= OUTPUT;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            OUTPUT: begin
                // Compute final result: DP[R][W][0] + DP[R][W][1]
                result <= dp_mem[R_max][W_max][0] + dp_mem[R_max][W_max][1];
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule