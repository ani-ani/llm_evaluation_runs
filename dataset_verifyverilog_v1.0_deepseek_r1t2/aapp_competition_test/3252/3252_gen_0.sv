module envelope_optimizer #(
    parameter N = 8,
    parameter K = 4,
    parameter DATA_W = 16,
    parameter RESULT_W = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_W-1:0] card_width [0:N-1],
    input wire [DATA_W-1:0] card_height [0:N-1],
    input wire [DATA_W-1:0] card_qty [0:N-1],
    input wire [3:0] num_env_types,
    output reg [RESULT_W-1:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUBSET = 3'd1;
    localparam [2:0] DP_INIT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [7:0] subset_idx;
    reg [RESULT_W-1:0] subset_waste [0:255];
    reg [RESULT_W-1:0] dp [0:255];
    reg [RESULT_W-1:0] next_dp [0:255];
    reg [DATA_W-1:0] max_w, max_h;
    reg [RESULT_W-1:0] sum_qty;
    reg [RESULT_W-1:0] sum_area;
    reg [7:0] mask;
    reg [7:0] submask;
    wire [3:0] t;
    reg [3:0] t_reg;
    reg [3:0] t_counter;
    reg [7:0] i;
    reg [RESULT_W-1:0] env_area;
    reg [RESULT_W-1:0] candidate;
    reg sub_iteration;
    
    assign t = t_reg;
    
    // Memory initialization 
    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (m = 0; m < 256; m = m + 1) begin
                subset_waste[m] <= {RESULT_W{1'b0}};
                dp[m] <= {RESULT_W{1'b0}};
                next_dp[m] <= {RESULT_W{1'b0}};
            end
        end
    end
    
    // Subset calculation comb
    always @(*) begin
        max_w = {DATA_W{1'b0}};
        max_h = {DATA_W{1'b0}};
        sum_qty = {RESULT_W{1'b0}};
        sum_area = {RESULT_W{1'b0}};
        
        // Compute max dimensions
        for (i = 0; i < N; i = i + 1) begin
            if (subset_idx[i]) begin
                if (card_width[i] > max_w)
                    max_w = card_width[i];
                if (card_height[i] > max_h)
                    max_h = card_height[i];
                sum_qty = sum_qty + card_qty[i];
                sum_area = sum_area + (card_qty[i] * (card_width[i] * card_height[i]));
            end
        end
        env_area = max_w * max_h;
    end
    
    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_W{1'b0}};
            subset_idx <= 8'd0;
            t_reg <= 4'd0;
            mask <= 8'd0;
            submask <= 8'd0;
            t_counter <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        subset_idx <= 8'd0;
                    end
                end
                
                COMPUTE_SUBSET: begin
                    subset_waste[subset_idx] <= (env_area * sum_qty) - sum_area;
                    if (subset_idx == 8'd255)
                        subset_idx <= 8'd0;
                    else
                        subset_idx <= subset_idx + 8'd1;
                end
                
                DP_INIT: begin
                    if (subset_idx == 8'd255) begin
                        subset_idx <= 8'd0;
                        t_reg <= 4'd1;
                    end else if (subset_idx == 8'd0) begin
                        dp[subset_idx] <= {RESULT_W{1'b0}};
                        subset_idx <= subset_idx + 8'd1;
                    end else begin
                        dp[subset_idx] <= {RESULT_W{1'b1}} >> 1;  // Max value
                        subset_idx <= subset_idx + 8'd1;
                    end
                end
                
                DP_COMPUTE: begin
                    if (t_reg <= num_env_types) begin
                        if (mask == 8'd0) begin
                            next_dp[0] <= dp[0];
                            submask <= mask;
                        end
                        
                        if (mask > 8'd0) begin
                            if (submask == mask) begin
                                submask <= (submask - 8'd1) & mask;
                                next_dp[mask] <= (subset_waste[mask] + dp[8'd0]) < next_dp[mask] ? (subset_waste[mask] + dp[8'd0]) : next_dp[mask];
                            end else if (submask != 8'd0) begin
                                candidate = subset_waste[submask] + dp[mask ^ submask];
                                if (candidate < next_dp[mask])
                                    next_dp[mask] <= candidate;
                                submask <= (submask - 8'd1) & mask;
                            end
                        end
                        
                        if (mask == 8'd255) begin
                            mask <= 8'd0;
                            t_reg <= t_reg + 4'd1;
                            if (t_reg < num_env_types) begin
                                for (m = 0; m < 256; m = m + 1)
                                    dp[m] <= next_dp[m];
                            end
                        end else begin
                            mask <= mask + 8'd1;
                            submask <= mask;
                            next_dp[mask] <= dp[mask];
                        end
                    end
                end
                
                FINISH: begin
                    result <= dp[255];
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: 
                if (start)
                    next_state = COMPUTE_SUBSET;
            
            COMPUTE_SUBSET:
                if (subset_idx == 8'd255)
                    next_state = DP_INIT;
            
            DP_INIT:
                if (subset_idx == 8'd255)
                    next_state = DP_COMPUTE;
            
            DP_COMPUTE:
                if (t_reg > num_env_types)
                    next_state = FINISH;
            
            FINISH:
                next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule