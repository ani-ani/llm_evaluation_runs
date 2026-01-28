module ShippingOptimizer #(
    parameter MAX_N = 4,
    parameter MAX_S = 4,
    parameter MAX_T = 4,
    parameter MAX_M = 6,
    parameter DATA_WIDTH = 32
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] s,
    input [3:0] t,
    input [3:0] a,
    input [3:0] b,
    input [3:0] emp_loc_0,
    input [3:0] emp_loc_1,
    input [3:0] emp_loc_2,
    input [3:0] emp_loc_3,
    input [3:0] cli_loc_0,
    input [3:0] cli_loc_1,
    input [3:0] cli_loc_2,
    input [3:0] cli_loc_3,
    input [3:0] edge_u_0,
    input [3:0] edge_v_0,
    input [3:0] edge_u_1,
    input [3:0] edge_v_1,
    input [3:0] edge_u_2,
    input [3:0] edge_v_2,
    input [3:0] edge_u_3,
    input [3:0] edge_v_3,
    input [3:0] edge_u_4,
    input [3:0] edge_v_4,
    input [3:0] edge_u_5,
    input [3:0] edge_v_5,
    input [31:0] edge_d_0,
    input [31:0] edge_d_1,
    input [31:0] edge_d_2,
    input [31:0] edge_d_3,
    input [31:0] edge_d_4,
    input [31:0] edge_d_5,
    output reg [31:0] total_distance,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_DIST     = 4'd1;
    localparam [3:0] INIT_DIST2    = 4'd2;
    localparam [3:0] FLOYD_K_LOOP  = 4'd3;
    localparam [3:0] FLOYD_I_LOOP  = 4'd4;
    localparam [3:0] FLOYD_J_LOOP  = 4'd5;
    localparam [3:0] FLOYD_UPDATE  = 4'd6;
    localparam [3:0] CALC_COST     = 4'd7;
    localparam [3:0] DP_INIT       = 4'd8;
    localparam [3:0] DP_CLIENT     = 4'd9;
    localparam [3:0] DP_MASK       = 4'd10;
    localparam [3:0] DP_EMP        = 4'd11;
    localparam [3:0] DP_UPDATE     = 4'd12;
    localparam [3:0] FIND_MIN      = 4'd13;
    localparam [3:0] FINISH        = 4'd14;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Data structures
    reg [DATA_WIDTH-1:0] dist [0:MAX_N-1][0:MAX_N-1];
    reg [DATA_WIDTH-1:0] cost [0:MAX_S-1][0:MAX_T-1];
    reg [DATA_WIDTH-1:0] dp [0:MAX_T][0:(1<<MAX_S)-1];
    reg [DATA_WIDTH-1:0] next_dp [0:(1<<MAX_S)-1];
    reg [DATA_WIDTH-1:0] current_dp [0:(1<<MAX_S)-1];
    
    // Loop indices
    reg [2:0] i_idx;
    reg [2:0] j_idx;
    reg [2:0] k_idx;
    reg [2:0] emp_idx;
    reg [2:0] cli_idx;
    reg [3:0] mask;
    reg [2:0] e_idx;
    reg [2:0] c_idx;
    reg [2:0] m_idx;
    
    // Temp variables for Floyd-Warshall
    reg [DATA_WIDTH-1:0] new_dist;
    reg [DATA_WIDTH-1:0] dist_ik;
    reg [DATA_WIDTH-1:0] dist_kj;
    reg [DATA_WIDTH-1:0] sum_dist;
    
    // Constants
    localparam [DATA_WIDTH-1:0] INF = 32'h7FFFFFFF;
    localparam [DATA_WIDTH-1:0] ZERO = 32'd0;
    
    // Temporary edge storage
    reg [3:0] edge_u_reg [0:MAX_M-1];
    reg [3:0] edge_v_reg [0:MAX_M-1];
    reg [DATA_WIDTH-1:0] edge_d_reg [0:MAX_M-1];
    reg [3:0] emp_loc_reg [0:MAX_S-1];
    reg [3:0] cli_loc_reg [0:MAX_T-1];
    
    reg edge_init_done;
    reg emp_init_done;
    reg cli_init_done;
    
    reg [10:0] temp_sum;
    reg [DATA_WIDTH-1:0] best_dp;
    
    integer bit_check;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_distance <= 32'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            k_idx <= 3'd0;
            emp_idx <= 3'd0;
            cli_idx <= 3'd0;
            mask <= 4'd0;
            e_idx <= 3'd0;
            c_idx <= 3'd0;
            m_idx <= 3'd0;
            new_dist <= 32'd0;
            dist_ik <= 32'd0;
            dist_kj <= 32'd0;
            sum_dist <= 32'd0;
            edge_init_done <= 1'b0;
            emp_init_done <= 1'b0;
            cli_init_done <= 1'b0;
            temp_sum <= 11'd0;
            best_dp <= 32'd0;
            bit_check <= 0;
            
            // Initialize dist array
            for (i_idx = 0; i_idx < MAX_N; i_idx = i_idx + 1) begin
                for (j_idx = 0; j_idx < MAX_N; j_idx = j_idx + 1) begin
                    dist[i_idx][j_idx] <= INF;
                end
            end
            
            // Initialize cost array
            for (emp_idx = 0; emp_idx < MAX_S; emp_idx = emp_idx + 1) begin
                for (cli_idx = 0; cli_idx < MAX_T; cli_idx = cli_idx + 1) begin
                    cost[emp_idx][cli_idx] <= INF;
                end
            end
            
            // Initialize dp array
            for (cli_idx = 0; cli_idx <= MAX_T; cli_idx = cli_idx + 1) begin
                for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                    dp[cli_idx][mask] <= INF;
                end
            end
            
            // Initialize current and next dp
            for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                current_dp[mask] <= INF;
                next_dp[mask] <= INF;
            end
            
            // Initialize edge and location arrays
            for (m_idx = 0; m_idx < MAX_M; m_idx = m_idx + 1) begin
                edge_u_reg[m_idx] <= 4'd0;
                edge_v_reg[m_idx] <= 4'd0;
                edge_d_reg[m_idx] <= 32'd0;
            end
            
            for (emp_idx = 0; emp_idx < MAX_S; emp_idx = emp_idx + 1) begin
                emp_loc_reg[emp_idx] <= 4'd0;
            end
            
            for (cli_idx = 0; cli_idx < MAX_T; cli_idx = cli_idx + 1) begin
                cli_loc_reg[cli_idx] <= 4'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    total_distance <= 32'd0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        // Store inputs
                        edge_u_reg[0] <= edge_u_0;
                        edge_v_reg[0] <= edge_v_0;
                        edge_d_reg[0] <= edge_d_0;
                        edge_u_reg[1] <= edge_u_1;
                        edge_v_reg[1] <= edge_v_1;
                        edge_d_reg[1] <= edge_d_1;
                        edge_u_reg[2] <= edge_u_2;
                        edge_v_reg[2] <= edge_v_2;
                        edge_d_reg[2] <= edge_d_2;
                        edge_u_reg[3] <= edge_u_3;
                        edge_v_reg[3] <= edge_v_3;
                        edge_d_reg[3] <= edge_d_3;
                        edge_u_reg[4] <= edge_u_4;
                        edge_v_reg[4] <= edge_v_4;
                        edge_d_reg[4] <= edge_d_4;
                        edge_u_reg[5] <= edge_u_5;
                        edge_v_reg[5] <= edge_v_5;
                        edge_d_reg[5] <= edge_d_5;
                        
                        emp_loc_reg[0] <= emp_loc_0;
                        emp_loc_reg[1] <= emp_loc_1;
                        emp_loc_reg[2] <= emp_loc_2;
                        emp_loc_reg[3] <= emp_loc_3;
                        
                        cli_loc_reg[0] <= cli_loc_0;
                        cli_loc_reg[1] <= cli_loc_1;
                        cli_loc_reg[2] <= cli_loc_2;
                        cli_loc_reg[3] <= cli_loc_3;
                        
                        // Reset arrays
                        for (i_idx = 0; i_idx < MAX_N; i_idx = i_idx + 1) begin
                            for (j_idx = 0; j_idx < MAX_N; j_idx = j_idx + 1) begin
                                dist[i_idx][j_idx] <= INF;
                            end
                        end
                        
                        for (emp_idx = 0; emp_idx < MAX_S; emp_idx = emp_idx + 1) begin
                            for (cli_idx = 0; cli_idx < MAX_T; cli_idx = cli_idx + 1) begin
                                cost[emp_idx][cli_idx] <= INF;
                            end
                        end
                        
                        for (cli_idx = 0; cli_idx <= MAX_T; cli_idx = cli_idx + 1) begin
                            for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                                dp[cli_idx][mask] <= INF;
                            end
                        end
                        
                        for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                            current_dp[mask] <= INF;
                            next_dp[mask] <= INF;
                        end
                        
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        k_idx <= 3'd0;
                        emp_idx <= 3'd0;
                        cli_idx <= 3'd0;
                        mask <= 4'd0;
                        e_idx <= 3'd0;
                        c_idx <= 3'd0;
                        m_idx <= 3'd0;
                        edge_init_done <= 1'b0;
                        emp_init_done <= 1'b0;
                        cli_init_done <= 1'b0;
                        
                        state <= INIT_DIST;
                    end
                end
                
                INIT_DIST: begin
                    // Set diagonal to 0
                    if (i_idx < n && i_idx < MAX_N) begin
                        dist[i_idx][i_idx] <= ZERO;
                        i_idx <= i_idx + 1;
                    end else begin
                        i_idx <= 3'd0;
                        m_idx <= 3'd0;
                        state <= INIT_DIST2;
                    end
                end
                
                INIT_DIST2: begin
                    // Set edges
                    if (m_idx < m && m_idx < MAX_M) begin
                        if (edge_u_reg[m_idx] > 4'd0 && edge_u_reg[m_idx] <= n && 
                            edge_v_reg[m_idx] > 4'd0 && edge_v_reg[m_idx] <= n) begin
                            dist[edge_u_reg[m_idx] - 1][edge_v_reg[m_idx] - 1] <= edge_d_reg[m_idx];
                            dist[edge_v_reg[m_idx] - 1][edge_u_reg[m_idx] - 1] <= edge_d_reg[m_idx];
                        end
                        m_idx <= m_idx + 1;
                    end else begin
                        k_idx <= 3'd0;
                        i_idx <= 3'd0;
                        j_idx <= 3'd0;
                        state <= FLOYD_K_LOOP;
                    end
                end
                
                FLOYD_K_LOOP: begin
                    if (k_idx < n && k_idx < MAX_N) begin
                        i_idx <= 3'd0;
                        state <= FLOYD_I_LOOP;
                    end else begin
                        // Floyd done, calculate cost matrix
                        emp_idx <= 3'd0;
                        cli_idx <= 3'd0;
                        state <= CALC_COST;
                    end
                end
                
                FLOYD_I_LOOP: begin
                    if (i_idx < n && i_idx < MAX_N) begin
                        j_idx <= 3'd0;
                        state <= FLOYD_J_LOOP;
                    end else begin
                        k_idx <= k_idx + 1;
                        state <= FLOYD_K_LOOP;
                    end
                end
                
                FLOYD_J_LOOP: begin
                    if (j_idx < n && j_idx < MAX_N) begin
                        state <= FLOYD_UPDATE;
                    end else begin
                        i_idx <= i_idx + 1;
                        state <= FLOYD_I_LOOP;
                    end
                end
                
                FLOYD_UPDATE: begin
                    dist_ik <= dist[i_idx][k_idx];
                    dist_kj <= dist[k_idx][j_idx];
                    
                    if (dist_ik < INF && dist_kj < INF) begin
                        temp_sum <= dist_ik + dist_kj;
                        if (temp_sum < dist[i_idx][j_idx]) begin
                            dist[i_idx][j_idx] <= temp_sum;
                        end
                    end
                    
                    j_idx <= j_idx + 1;
                    state <= FLOYD_J_LOOP;
                end
                
                CALC_COST: begin
                    if (emp_idx < s && emp_idx < MAX_S && cli_idx < t && cli_idx < MAX_T) begin
                        // Calculate cost from a and b
                        if (emp_loc_reg[emp_idx] > 4'd0 && emp_loc_reg[emp_idx] <= n &&
                            cli_loc_reg[cli_idx] > 4'd0 && cli_loc_reg[cli_idx] <= n &&
                            a > 4'd0 && a <= n && b > 4'd0 && b <= n) begin
                            
                            reg [DATA_WIDTH-1:0] cost_a;
                            reg [DATA_WIDTH-1:0] cost_b;
                            reg [DATA_WIDTH-1:0] emp_dist_a;
                            reg [DATA_WIDTH-1:0] emp_dist_b;
                            reg [DATA_WIDTH-1:0] cli_dist_a;
                            reg [DATA_WIDTH-1:0] cli_dist_b;
                            
                            emp_dist_a <= dist[a-1][emp_loc_reg[emp_idx]-1];
                            cli_dist_a <= dist[a-1][cli_loc_reg[cli_idx]-1];
                            emp_dist_b <= dist[b-1][emp_loc_reg[emp_idx]-1];
                            cli_dist_b <= dist[b-1][cli_loc_reg[cli_idx]-1];
                            
                            if (emp_dist_a < INF && cli_dist_a < INF) begin
                                cost_a <= emp_dist_a + cli_dist_a;
                            end else begin
                                cost_a <= INF;
                            end
                            
                            if (emp_dist_b < INF && cli_dist_b < INF) begin
                                cost_b <= emp_dist_b + cli_dist_b;
                            end else begin
                                cost_b <= INF;
                            end
                            
                            if (cost_a < cost_b) begin
                                cost[emp_idx][cli_idx] <= cost_a;
                            end else begin
                                cost[emp_idx][cli_idx] <= cost_b;
                            end
                        end
                    end
                    
                    if (cli_idx < t && cli_idx < MAX_T) begin
                        cli_idx <= cli_idx + 1;
                    end else if (emp_idx < s && emp_idx < MAX_S) begin
                        emp_idx <= emp_idx + 1;
                        cli_idx <= 3'd0;
                    end else begin
                        // Initialize DP
                        for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                            if (mask == 0) begin
                                dp[0][mask] <= 32'd0;
                            end else begin
                                dp[0][mask] <= INF;
                            end
                            current_dp[mask] <= (mask == 0) ? 32'd0 : INF;
                        end
                        cli_idx <= 3'd0;
                        state <= DP_CLIENT;
                    end
                end
                
                DP_CLIENT: begin
                    if (cli_idx < t && cli_idx < MAX_T) begin
                        // Reset next_dp
                        for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                            next_dp[mask] <= INF;
                        end
                        mask <= 4'd0;
                        state <= DP_MASK;
                    end else begin
                        // Find minimum from dp[t][mask] where popcount(mask) == t
                        best_dp <= INF;
                        mask <= 4'd0;
                        state <= FIND_MIN;
                    end
                end
                
                DP_MASK: begin
                    if (mask < (1 << s) && mask < (1 << MAX_S)) begin
                        // Check if dp[cli_idx][mask] is valid
                        if (current_dp[mask] < INF) begin
                            emp_idx <= 3'd0;
                            state <= DP_EMP;
                        end else begin
                            mask <= mask + 1;
                            state <= DP_MASK;
                        end
                    end else begin
                        // Update current_dp
                        for (mask = 0; mask < (1 << MAX_S); mask = mask + 1) begin
                            current_dp[mask] <= next_dp[mask];
                        end
                        cli_idx <= cli_idx + 1;
                        state <= DP_CLIENT;
                    end
                end
                
                DP_EMP: begin
                    if (emp_idx < s && emp_idx < MAX_S) begin
                        // Check if employee not used
                        if ((mask & (1 << emp_idx)) == 0) begin
                            // Update next_dp
                            if (current_dp[mask] < INF && cost[emp_idx][cli_idx] < INF) begin
                                reg [10:0] new_val;
                                new_val = current_dp[mask] + cost[emp_idx][cli_idx];
                                if (new_val < next_dp[mask | (1 << emp_idx)]) begin
                                    next_dp[mask | (1 << emp_idx)] <= new_val;
                                end
                            end
                        end
                        emp_idx <= emp_idx + 1;
                    end else begin
                        mask <= mask + 1;
                        state <= DP_MASK;
                    end
                end
                
                FIND_MIN: begin
                    if (mask < (1 << s) && mask < (1 << MAX_S)) begin
                        // Check popcount
                        bit_check = 0;
                        for (e_idx = 0; e_idx < s && e_idx < MAX_S; e_idx = e_idx + 1) begin
                            if (mask[e_idx]) begin
                                bit_check = bit_check + 1;
                            end
                        end
                        
                        if (bit_check == t) begin
                            if (dp[t][mask] < best_dp) begin
                                best_dp <= dp[t][mask];
                            end
                        end
                        mask <= mask + 1;
                    end else begin
                        total_distance <= best_dp;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Increment cycle counter
            if (state != IDLE && state != FINISH) begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 10'd1;
                end else begin
                    // Timeout - go to finish
                    total_distance <= 32'hFFFFFFFF;
                    state <= FINISH;
                end
            end
        end
    end

endmodule