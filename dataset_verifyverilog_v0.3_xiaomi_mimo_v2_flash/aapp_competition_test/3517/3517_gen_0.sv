module airplane_construction(
    input clk,
    input rst_n,
    input start,
    input [15:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] dep_mask_0, dep_mask_1, dep_mask_2, dep_mask_3, dep_mask_4, dep_mask_5, dep_mask_6, dep_mask_7,
    output reg [31:0] result,
    output reg done
);

    // Internal arrays for a and dependency masks
    reg [31:0] a [0:7];
    reg [7:0] dep_mask [0:7];
    
    // State machine states
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] SETUP       = 4'd1;
    localparam [3:0] COMPUTE_DP  = 4'd2;
    localparam [3:0] WAIT_DONE   = 4'd3;
    localparam [3:0] DONE        = 4'd4;
    
    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] k;
    reg [3:0] i;
    reg [31:0] dp [0:7];
    reg [31:0] max_val;
    reg [31:0] min_val;
    reg [2:0] j;
    reg [2:0] calc_j;
    reg [2:0] calc_idx;
    reg [31:0] dp_max;
    reg [31:0] dp_val;
    reg [31:0] a_val;
    reg [31:0] temp_result;
    reg [7:0] deps;
    reg [2:0] dep_idx;
    
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            k <= 4'd0;
            i <= 4'd0;
            min_val <= 32'hFFFFFFFF;
            max_val <= 32'd0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                a[idx] <= 32'd0;
                dep_mask[idx] <= 8'd0;
                dp[idx] <= 32'd0;
            end
            j <= 3'd0;
            calc_j <= 3'd0;
            calc_idx <= 3'd0;
            dp_max <= 32'd0;
            dp_val <= 32'd0;
            a_val <= 32'd0;
            temp_result <= 32'd0;
            deps <= 8'd0;
            dep_idx <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                SETUP: begin
                    // Zero-extend a values to 32-bit
                    a[0] <= {16'b0, a_0};
                    a[1] <= {16'b0, a_1};
                    a[2] <= {16'b0, a_2};
                    a[3] <= {16'b0, a_3};
                    a[4] <= {16'b0, a_4};
                    a[5] <= {16'b0, a_5};
                    a[6] <= {16'b0, a_6};
                    a[7] <= {16'b0, a_7};
                    dep_mask[0] <= dep_mask_0;
                    dep_mask[1] <= dep_mask_1;
                    dep_mask[2] <= dep_mask_2;
                    dep_mask[3] <= dep_mask_3;
                    dep_mask[4] <= dep_mask_4;
                    dep_mask[5] <= dep_mask_5;
                    dep_mask[6] <= dep_mask_6;
                    dep_mask[7] <= dep_mask_7;
                    // Initialize
                    k <= 4'd0;
                    min_val <= 32'hFFFFFFFF;
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        dp[idx] <= 32'd0;
                    end
                end
                
                COMPUTE_DP: begin
                    case (i)
                        4'd0: begin
                            dp[0] <= (k == 4'd0) ? 32'd0 : a[0];
                        end
                        default: begin
                            // dp[i] = max(dp[j]) where deps[i][j] = 1
                            dp[i] <= dp_max + ((i == k) ? 32'd0 : a_val);
                        end
                    endcase
                end
                
                WAIT_DONE: begin
                    // Update min_val if needed
                    if (k == 4'd0) begin
                        min_val <= dp[7];
                    end else if (dp[7] < min_val) begin
                        min_val <= dp[7];
                    end
                end
                
                DONE: begin
                    result <= min_val;
                    done <= 1'b1;
                end
                
                default: begin
                    // Handle default case
                    dp_max <= 32'd0;
                    temp_result <= 32'd0;
                end
            endcase
        end
    end

    // Combinational logic for state transitions and calculations
    always @(*) begin
        // Default assignments
        next_state = state;
        dp_max = 32'd0;
        deps = 8'd0;
        dp_val = 32'd0;
        a_val = a[i];
        temp_result = 32'd0;
        dep_idx = 3'd0;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                next_state = COMPUTE_DP;
                i = 4'd0;
                calc_j = 3'd0;
                calc_idx = 3'd0;
                dp_max = 32'd0;
            end
            
            COMPUTE_DP: begin
                if (i < 8) begin
                    if (i == 4'd0) begin
                        next_state = COMPUTE_DP;
                        i = 4'd1;
                    end else begin
                        // Check dependency mask for i
                        deps = dep_mask[i];
                        dp_max = 32'd0;
                        for (calc_j = 3'd0; calc_j < 3'd8; calc_j = calc_j + 3'd1) begin
                            if (deps[calc_j]) begin
                                dp_val = dp[calc_j];
                                if (dp_val > dp_max) begin
                                    dp_max = dp_val;
                                end
                            end
                        end
                        next_state = COMPUTE_DP;
                        i = i + 4'd1;
                    end
                end else begin
                    next_state = WAIT_DONE;
                end
            end
            
            WAIT_DONE: begin
                if (k < 7) begin
                    next_state = SETUP;
                    k = k + 4'd1;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule