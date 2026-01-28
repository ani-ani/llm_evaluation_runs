module ShippingOptimizer (
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

    /* State definitions */
    localparam [4:0] 
        IDLE          = 5'd0,
        INIT_DIST     = 5'd1,
        SET_EDGES     = 5'd2,
        FLOYD_K       = 5'd3,
        FLOYD_I       = 5'd4,
        FLOYD_J       = 5'd5,
        COST_START    = 5'd6,
        COST_I        = 5'd7,
        COST_J        = 5'd8,
        ASN_INIT      = 5'd9,
        ASN_CLIENT    = 5'd10,
        ASN_MASK      = 5'd11,
        ASN_EMPLOYEE  = 5'd12,
        ASN_NEXT_EMPL = 5'd13,
        ASN_NEXT_MASK = 5'd14,
        ASN_NEXT_CLNT = 5'd15,
        FIND_MIN      = 5'd16,
        FINISH        = 5'd17;
    
    /* Internal registers */
    reg [4:0]   state;
    reg [3:0]   edge_cnt;
    reg [3:0]   k, i, j;
    reg [3:0]   emp_idx, cli_idx;
    reg [3:0]   client_cnt, current_mask;
    reg [2:0]   employee_idx;
    reg [31:0]  dist [0:3][0:3];
    reg [31:0]  cost [0:3][0:3];
    reg [3:0]   emp_loc_r[0:3];
    reg [3:0]   cli_loc_r[0:3];
    reg [31:0]  dp[0:4][0:15];
    reg [31:0]  temp_sum;
    reg [15:0]  cycle_count;
    
    /* Edge storage */
    reg [3:0]   edge_u_r [0:5];
    reg [3:0]   edge_v_r [0:5];
    reg [31:0]  edge_d_r [0:5];
    
    /* Combinational signals */
    wire [31:0] new_dist;
    wire [31:0] path1, path2;
    wire [3:0] emp_loc_idx;
    wire [3:0] cli_loc_idx;
    wire employee_in_mask;
    wire [3:0] new_mask;
    
    assign new_mask = current_mask | (1 << employee_idx);
    assign new_dist = dist[i][k] + dist[k][j];
    assign path1 = dist[a-4'd1][emp_loc_r[emp_idx]-4'd1] + dist[a-4'd1][cli_loc_r[cli_idx]-4'd1];
    assign path2 = dist[b-4'd1][emp_loc_r[emp_idx]-4'd1] + dist[b-4'd1][cli_loc_r[cli_idx]-4'd1];
    assign employee_in_mask = current_mask[employee_idx];
    
    integer x, y, z, w;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            /* Reset everything */
            state <= IDLE;
            done <= 1'b0;
            total_distance <= 32'd0;
            cycle_count <= 16'd0;
            
            /* Initialize dist array */
            for (x = 0; x < 4; x = x + 1) begin
                for (y = 0; y < 4; y = y + 1) begin
                    dist[x][y] <= 32'h7FFFFFFF;
                end
            end
            
            /* Initialize dp array */
            for (x = 0; x <= 4; x = x + 1) begin
                for (y = 0; y < 16; y = y + 1) begin
                    dp[x][y] <= 32'h7FFFFFFF;
                end
            end
            
            /* Clear edge registers */
            edge_u_r[0] <= 4'd0; edge_u_r[1] <= 4'd0; edge_u_r[2] <= 4'd0;
            edge_u_r[3] <= 4'd0; edge_u_r[4] <= 4'd0; edge_u_r[5] <= 4'd0;
            edge_v_r[0] <= 4'd0; edge_v_r[1] <= 4'd0; edge_v_r[2] <= 4'd0;
            edge_v_r[3] <= 4'd0; edge_v_r[4] <= 4'd0; edge_v_r[5] <= 4'd0;
            edge_d_r[0] <= 32'd0; edge_d_r[1] <= 32'd0; edge_d_r[2] <= 32'd0;
            edge_d_r[3] <= 32'd0; edge_d_r[4] <= 32'd0; edge_d_r[5] <= 32'd0;
            
            /* Clear employee/client locs */
            emp_loc_r[0] <= 4'd0; emp_loc_r[1] <= 4'd0;
            emp_loc_r[2] <= 4'd0; emp_loc_r[3] <= 4'd0;
            cli_loc_r[0] <= 4'd0; cli_loc_r[1] <= 4'd0;
            cli_loc_r[2] <= 4'd0; cli_loc_r[3] <= 4'd0;
        end
        else begin
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        /* Capture inputs */
                        edge_u_r[0] <= edge_u_0; edge_v_r[0] <= edge_v_0; edge_d_r[0] <= edge_d_0;
                        edge_u_r[1] <= edge_u_1; edge_v_r[1] <= edge_v_1; edge_d_r[1] <= edge_d_1;
                        edge_u_r[2] <= edge_u_2; edge_v_r[2] <= edge_v_2; edge_d_r[2] <= edge_d_2;
                        edge_u_r[3] <= edge_u_3; edge_v_r[3] <= edge_v_3; edge_d_r[3] <= edge_d_3;
                        edge_u_r[4] <= edge_u_4; edge_v_r[4] <= edge_v_4; edge_d_r[4] <= edge_d_4;
                        edge_u_r[5] <= edge_u_5; edge_v_r[5] <= edge_v_5; edge_d_r[5] <= edge_d_5;
                        
                        emp_loc_r[0] <= emp_loc_0; emp_loc_r[1] <= emp_loc_1;
                        emp_loc_r[2] <= emp_loc_2; emp_loc_r[3] <= emp_loc_3;
                        cli_loc_r[0] <= cli_loc_0; cli_loc_r[1] <= cli_loc_1;
                        cli_loc_r[2] <= cli_loc_2; cli_loc_r[3] <= cli_loc_3;
                        
                        /* Initialize dist diagonal */
                        for (x = 0; x < 4; x = x + 1) begin
                            if (x < n) dist[x][x] <= 32'd0;
                        end
                        
                        state <= INIT_DIST;
                        edge_cnt <= 4'd0;
                        cycle_count <= 16'd0;
                    end
                end
                
                INIT_DIST: begin
                    /* Set edges from captured edge arrays */
                    if (edge_cnt < m) begin
                        dist[edge_u_r[edge_cnt]-4'd1][edge_v_r[edge_cnt]-4'd1] <= edge_d_r[edge_cnt];
                        dist[edge_v_r[edge_cnt]-4'd1][edge_u_r[edge_cnt]-4'd1] <= edge_d_r[edge_cnt];
                        edge_cnt <= edge_cnt + 4'd1;
                    end
                    else begin
                        k <= 4'd0;
                        state <= FLOYD_K;
                    end
                end
                
                FLOYD_K: begin
                    if (k < n) begin
                        i <= 4'd0;
                        state <= FLOYD_I;
                    end
                    else begin
                        emp_idx <= 4'd0;
                        cli_idx <= 4'd0;
                        state <= COST_START;
                    end
                end
                
                FLOYD_I: begin
                    if (i < n) begin
                        j <= 4'd0;
                        state <= FLOYD_J;
                    end
                    else begin
                        k <= k + 4'd1;
                        state <= FLOYD_K;
                    end
                end
                
                FLOYD_J: begin
                    if (j < n) begin
                        if (new_dist < dist[i][j]) begin
                            dist[i][j] <= new_dist;
                        end
                        j <= j + 4'd1;
                    end
                    else begin
                        i <= i + 4'd1;
                        state <= FLOYD_I;
                    end
                end
                
                COST_START: begin
                    emp_idx <= 4'd0;
                    state <= COST_I;
                end
                
                COST_I: begin
                    if (emp_idx < s) begin
                        cli_idx <= 4'd0;
                        state <= COST_J;
                    end
                    else begin
                        client_cnt <= 4'd0;
                        state <= ASN_INIT;
                    end
                end
                
                COST_J: begin
                    if (cli_idx < t) begin
                        cost[emp_idx][cli_idx] <= (path1 < path2) ? path1 : path2;
                        cli_idx <= cli_idx + 4'd1;
                    end
                    else begin
                        emp_idx <= emp_idx + 4'd1;
                        state <= COST_I;
                    end
                end
                
                ASN_INIT: begin
                    /* Initialize dp[0][0] = 0 */
                    dp[0][0] <= 32'd0;
                    client_cnt <= 4'd0;
                    state <= ASN_CLIENT;
                end
                
                ASN_CLIENT: begin
                    if (client_cnt < t) begin
                        current_mask <= 4'd0;
                        state <= ASN_MASK;
                    end
                    else begin
                        state <= FIND_MIN;
                    end
                end
                
                ASN_MASK: begin
                    if (current_mask < 16) begin
                        if (dp[client_cnt][current_mask] != 32'h7FFFFFFF) begin
                            employee_idx <= 3'd0;
                            state <= ASN_EMPLOYEE;
                        end
                        else begin
                            current_mask <= current_mask + 4'd1;
                        end
                    end
                    else begin
                        client_cnt <= client_cnt + 4'd1;
                        state <= ASN_CLIENT;
                    end
                end
                
                ASN_EMPLOYEE: begin
                    if (employee_idx < s) begin
                        if (!employee_in_mask) begin
                            temp_sum <= dp[client_cnt][current_mask] + cost[employee_idx][client_cnt];
                            state <= ASN_UPDATE;
                        end
                        else begin
                            employee_idx <= employee_idx + 3'd1;
                        end
                    end
                    else begin
                        current_mask <= current_mask + 4'd1;
                        state <= ASN_MASK;
                    end
                end
                
                ASN_UPDATE: begin
                    if (temp_sum < dp[client_cnt+1][new_mask]) begin
                        dp[client_cnt+1][new_mask] <= temp_sum;
                    end
                    employee_idx <= employee_idx + 3'd1;
                    state <= ASN_EMPLOYEE;
                end
                
                FIND_MIN: begin
                    total_distance <= 32'h7FFFFFFF;
                    for (z = 0; z < 16; z = z +1) begin
                        if (((z[0] + z[1] + z[2] + z[3]) == t) && (dp[t][z] < total_distance)) begin
                            total_distance <= dp[t][z];
                        end
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            /* Timeout protection */
            if (cycle_count > 1000) begin
                total_distance <= 32'h7FFFFFFF;
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
endmodule