module friend_group_checker #(
    parameter MAX_N = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] p,
    input wire [3:0] q,
    input wire [7:0] adj [0:MAX_N-1],
    output reg done,
    output reg valid,
    output reg [2:0] group_id [0:MAX_N-1]
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] DP = 3'd2;
    localparam [2:0] RECONSTRUCT = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Precompute valid groups
    reg [7:0] valid_group [0:255];
    reg [7:0] current_mask;
    reg [7:0] submask;
    reg [7:0] dp [0:255];
    reg [7:0] pred [0:255];
    reg [7:0] temp_mask;
    reg [7:0] temp_submask;
    reg [7:0] temp_pred;
    reg [7:0] temp_valid;
    reg [7:0] temp_dp;
    reg [7:0] temp_group;
    reg [7:0] temp_count;
    reg [7:0] temp_cross;
    reg [7:0] temp_size;
    reg [7:0] temp_node;
    reg [7:0] temp_edge;
    reg [7:0] temp_outside;
    reg [7:0] temp_sum;
    reg [7:0] temp_popcount;
    reg [7:0] temp_i;
    reg [7:0] temp_j;
    reg [7:0] temp_k;
    reg [7:0] temp_l;
    reg [7:0] temp_m;
    reg [7:0] temp_n;
    reg [7:0] temp_o;
    reg [7:0] temp_p;
    reg [7:0] temp_q;
    reg [7:0] temp_r;
    reg [7:0] temp_s;
    reg [7:0] temp_t;
    reg [7:0] temp_u;
    reg [7:0] temp_v;
    reg [7:0] temp_w;
    reg [7:0] temp_x;
    reg [7:0] temp_y;
    reg [7:0] temp_z;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 16'd0;
            
            // Initialize all registers
            for (temp_i = 0; temp_i < 8; temp_i = temp_i + 1) begin
                group_id[temp_i] <= 3'd0;
            end
            
            for (temp_i = 0; temp_i < 256; temp_i = temp_i + 1) begin
                valid_group[temp_i] <= 1'b0;
                dp[temp_i] <= 1'b0;
                pred[temp_i] <= 8'd0;
            end
            
            current_mask <= 8'd0;
            submask <= 8'd0;
            temp_mask <= 8'd0;
            temp_submask <= 8'd0;
            temp_pred <= 8'd0;
            temp_valid <= 8'd0;
            temp_dp <= 8'd0;
            temp_group <= 8'd0;
            temp_count <= 8'd0;
            temp_cross <= 8'd0;
            temp_size <= 8'd0;
            temp_node <= 8'd0;
            temp_edge <= 8'd0;
            temp_outside <= 8'd0;
            temp_sum <= 8'd0;
            temp_popcount <= 8'd0;
            temp_i <= 8'd0;
            temp_j <= 8'd0;
            temp_k <= 8'd0;
            temp_l <= 8'd0;
            temp_m <= 8'd0;
            temp_n <= 8'd0;
            temp_o <= 8'd0;
            temp_p <= 8'd0;
            temp_q <= 8'd0;
            temp_r <= 8'd0;
            temp_s <= 8'd0;
            temp_t <= 8'd0;
            temp_u <= 8'd0;
            temp_v <= 8'd0;
            temp_w <= 8'd0;
            temp_x <= 8'd0;
            temp_y <= 8'd0;
            temp_z <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 16'd0;
                    
                    if (start) begin
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Precompute valid groups
                    if (current_mask == 8'd0) begin
                        current_mask <= 8'd1;
                    end else begin
                        // Check if current_mask is a valid group
                        temp_size <= 0;
                        temp_cross <= 0;
                        
                        for (temp_i = 0; temp_i < n; temp_i = temp_i + 1) begin
                            if (current_mask[temp_i]) begin
                                temp_size <= temp_size + 1'b1;
                                
                                // Count edges to nodes outside the group
                                temp_outside <= 0;
                                for (temp_j = 0; temp_j < n; temp_j = temp_j + 1) begin
                                    if (!current_mask[temp_j] && adj[temp_i][temp_j]) begin
                                        temp_outside <= temp_outside + 1'b1;
                                    end
                                end
                                temp_cross <= temp_cross + temp_outside;
                            end
                        end
                        
                        if (temp_size <= p && temp_cross <= q) begin
                            valid_group[current_mask] <= 1'b1;
                        end else begin
                            valid_group[current_mask] <= 1'b0;
                        end
                        
                        current_mask <= current_mask + 8'd1;
                        
                        if (current_mask == 8'd0) begin
                            current_mask <= 8'd1;
                            state <= DP;
                        end
                    end
                end

                DP: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Initialize DP
                    if (current_mask == 8'd0) begin
                        dp[8'd0] <= 1'b1;
                        current_mask <= 8'd1;
                    end else begin
                        // Compute DP for current_mask
                        temp_dp <= 1'b0;
                        temp_pred <= 8'd0;
                        
                        for (temp_i = 0; temp_i < 256; temp_i = temp_i + 1) begin
                            if (valid_group[temp_i] && (temp_i & current_mask) == temp_i) begin
                                temp_submask <= current_mask ^ temp_i;
                                if (dp[temp_submask]) begin
                                    temp_dp <= 1'b1;
                                    temp_pred <= temp_i;
                                end
                            end
                        end
                        
                        dp[current_mask] <= temp_dp;
                        pred[current_mask] <= temp_pred;
                        
                        current_mask <= current_mask + 8'd1;
                        
                        if (current_mask == 8'd0) begin
                            current_mask <= 8'd1;
                            
                            if (dp[{(n){1'b1}}]) begin
                                valid <= 1'b1;
                                state <= RECONSTRUCT;
                            end else begin
                                valid <= 1'b0;
                                state <= FINISH;
                            end
                        end
                    end
                end

                RECONSTRUCT: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Reconstruct partition
                    if (current_mask == 8'd0) begin
                        current_mask <= {(n){1'b1}};
                        temp_group <= 8'd0;
                    end else begin
                        temp_submask <= pred[current_mask];
                        
                        // Assign group IDs
                        for (temp_i = 0; temp_i < n; temp_i = temp_i + 1) begin
                            if (temp_submask[temp_i]) begin
                                group_id[temp_i] <= temp_group;
                            end
                        end
                        
                        temp_group <= temp_group + 8'd1;
                        current_mask <= current_mask ^ temp_submask;
                        
                        if (current_mask == 8'd0) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                valid <= 1'b0;
            end
        end
    end

endmodule