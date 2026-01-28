module envelope_optimizer #(
    parameter N = 8,
    parameter K = 4,
    parameter DATA_W = 16,
    parameter RESULT_W = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_W-1:0] card_width [N-1:0],
    input wire [DATA_W-1:0] card_height [N-1:0],
    input wire [DATA_W-1:0] card_qty [N-1:0],
    input wire [3:0] num_env_types,
    output reg [RESULT_W-1:0] result,
    output reg done
);

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUBSET = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Memory for subset waste calculation (2^N = 256 entries)
    reg [RESULT_W-1:0] subset_waste [0:255];
    reg [7:0] subset_idx;

    // DP arrays: dp[mask]
    reg [RESULT_W-1:0] dp [0:255];
    reg [RESULT_W-1:0] next_dp [0:255];

    // Helper variables
    reg [7:0] mask;
    reg [7:0] submask;
    reg [DATA_W-1:0] max_w;
    reg [DATA_W-1:0] max_h;
    reg [DATA_W*2-1:0] env_area;
    reg [RESULT_W-1:0] sum_qty;
    reg [RESULT_W-1:0] sum_area;
    reg [3:0] t;
    reg [7:0] i;
    reg [RESULT_W-1:0] candidate;
    reg [RESULT_W-1:0] min_val;
    reg [7:0] copy_idx;

    // Combinational logic for subset computation
    always @(*) begin
        // Calculate max width and height for current subset
        max_w = 0;
        max_h = 0;
        sum_qty = 0;
        sum_area = 0;
        
        for (i = 0; i < N; i = i + 1) begin
            if (subset_idx[i]) begin
                if (card_width[i] > max_w) max_w = card_width[i];
                if (card_height[i] > max_h) max_h = card_height[i];
                sum_qty = sum_qty + card_qty[i];
                sum_area = sum_area + (card_qty[i] * (card_width[i] * card_height[i]));
            end
        end
        
        env_area = max_w * max_h;
    end

    // Combinational logic for DP computation
    always @(*) begin
        candidate = 32'h7FFFFFFF;
        if (submask != 0 && subset_waste[submask] < 32'h7FFFFFFF && dp[mask ^ submask] < 32'h7FFFFFFF) begin
            candidate = subset_waste[submask] + dp[mask ^ submask];
        end
    end

    // Sequential state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_idx <= 0;
            t <= 0;
            done <= 0;
            result <= 0;
            mask <= 0;
            submask <= 0;
            copy_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        subset_idx <= 0;
                        t <= 1;
                    end
                end
                
                COMPUTE_SUBSET: begin
                    if (sum_qty > 0) begin
                        subset_waste[subset_idx] <= (env_area * sum_qty) - sum_area;
                    end else begin
                        subset_waste[subset_idx] <= 0;
                    end
                    
                    if (subset_idx == 8'd255) begin
                        subset_idx <= 0;
                    end else begin
                        subset_idx <= subset_idx + 8'd1;
                    end
                end
                
                DP_INIT: begin
                    if (subset_idx == 8'd0) begin
                        dp[0] <= 0;
                        subset_idx <= 8'd1;
                    end else if (subset_idx < 8'd255) begin
                        dp[subset_idx] <= 32'h7FFFFFFF;
                        subset_idx <= subset_idx + 8'd1;
                    end else begin
                        dp[255] <= 32'h7FFFFFFF;
                        subset_idx <= 0;
                        t <= 1;
                    end
                end
                
                DP_COMPUTE: begin
                    if (t <= num_env_types) begin
                        if (mask == 8'd0) begin
                            next_dp[0] <= dp[0];
                            mask <= 8'd1;
                        end else if (mask < 8'd255) begin
                            if (submask == 8'd0) begin
                                min_val <= 32'h7FFFFFFF;
                                submask <= mask;
                            end else if (submask > 8'd0) begin
                                if (candidate < min_val) begin
                                    min_val <= candidate;
                                end
                                
                                if (submask == mask) begin
                                    next_dp[mask] <= min_val;
                                    submask <= 8'd0;
                                    mask <= mask + 8'd1;
                                end else begin
                                    submask <= (submask - 8'd1) & mask;
                                end
                            end
                        end else begin
                            if (copy_idx < 8'd255) begin
                                dp[copy_idx] <= next_dp[copy_idx];
                                copy_idx <= copy_idx + 8'd1;
                            end else begin
                                dp[255] <= next_dp[255];
                                copy_idx <= 0;
                                mask <= 0;
                                submask <= 0;
                                t <= t + 4'd1;
                            end
                        end
                    end else begin
                        result <= dp[255];
                        done <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b0;
                end
            endcase
            
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_SUBSET;
            end
            
            COMPUTE_SUBSET: begin
                if (subset_idx == 8'd255) next_state = DP_INIT;
            end
            
            DP_INIT: begin
                if (subset_idx == 8'd255 && t == 4'd1) next_state = DP_COMPUTE;
            end
            
            DP_COMPUTE: begin
                if (t > num_env_types) next_state = FINISH;
            end
            
            FINISH: begin
                if (!done) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule