module treasure_island #(
    parameter MAX_N = 8,
    parameter MAX_M = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [MAX_N*MAX_M-1:0] grid_flat,
    output reg [1:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] FORWARD = 3'd2;
    localparam [2:0] BACKWARD = 3'd3;
    localparam [2:0] COUNT = 3'd4;
    localparam [2:0] CHECK = 3'd5;
    localparam [2:0] DONE_ST = 3'd6;

    reg [2:0] state;
    reg [MAX_M-1:0] grid [0:MAX_N-1];
    reg [MAX_M-1:0] reachable [0:MAX_N-1];
    reg [MAX_M-1:0] can_reach [0:MAX_N-1];
    reg [3:0] diag_cnt [0:14];
    
    reg [3:0] i, j;
    reg [3:0] diag_idx;
    reg path_exists;
    integer k; // For loop variable
    
    wire cell_forest;
    assign cell_forest = grid[i][j];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            i <= 4'd0;
            j <= 4'd0;
            path_exists <= 1'b0;
            diag_idx <= 4'd0;
            
            // Initialize all arrays
            for (k = 0; k < MAX_N; k = k + 1) begin
                grid[k] <= {MAX_M{1'b0}};
                reachable[k] <= {MAX_M{1'b0}};
                can_reach[k] <= {MAX_M{1'b0}};
            end
            
            for (k = 0; k < 15; k = k + 1) begin
                diag_cnt[k] <= 4'd0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 2'd0;
                    if (start) begin
                        state <= LOAD;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end
                
                LOAD: begin
                    if (i < n) begin
                        if (j < m) begin
                            grid[i][j] <= grid_flat[i*MAX_M + j];
                            reachable[i][j] <= 1'b0;
                            can_reach[i][j] <= 1'b0;
                            j <= j + 4'd1;
                        end
                        else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                    else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= FORWARD;
                    end
                end
                
                FORWARD: begin
                    if (i < n && j < m) begin
                        if (i == 4'd0 && j == 4'd0) begin
                            reachable[0][0] <= ~grid[0][0];
                        end
                        else if (!cell_forest) begin
                            if ((i > 4'd0 && reachable[i-4'd1][j]) || 
                                (j > 4'd0 && reachable[i][j-4'd1])) begin
                                reachable[i][j] <= 1'b1;
                            end
                        end
                        
                        if (j + 4'd1 < m) begin
                            j <= j + 4'd1;
                        end
                        else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                    else begin
                        if (reachable[n-4'd1][m-4'd1]) begin
                            path_exists <= 1'b1;
                            i <= n - 4'd1;
                            j <= m - 4'd1;
                            state <= BACKWARD;
                        end
                        else begin
                            result <= 2'd0;
                            state <= DONE_ST;
                        end
                    end
                end
                
                BACKWARD: begin
                    if (i >= 0 && j >= 0) begin
                        if (i == n-4'd1 && j == m-4'd1) begin
                            can_reach[i][j] <= ~grid[i][j];
                        end
                        else if (!cell_forest) begin
                            if ((i < n-4'd1 && can_reach[i+4'd1][j]) || 
                                (j < m-4'd1 && can_reach[i][j+4'd1])) begin
                                can_reach[i][j] <= 1'b1;
                            end
                        end
                        
                        if (j > 4'd0) begin
                            j <= j - 4'd1;
                        end
                        else begin
                            j <= m - 4'd1;
                            if (i > 4'd0) begin
                                i <= i - 4'd1;
                            end
                            else begin
                                i <= 4'd0;
                                j <= 4'd0;
                                state <= COUNT;
                            end
                        end
                    end
                    else begin
                        state <= COUNT;
                    end
                end
                
                COUNT: begin
                    if (i < n && j < m) begin
                        if (reachable[i][j] && can_reach[i][j] && !cell_forest) begin
                            diag_idx = i + j;
                            if (diag_idx < 4'd15) begin
                                diag_cnt[diag_idx] <= diag_cnt[diag_idx] + 4'd1;
                            end
                        end
                        
                        if (j + 4'd1 < m) begin
                            j <= j + 4'd1;
                        end
                        else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                    else begin
                        i <= 4'd0;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (i < (n + m - 4'd2)) begin
                        if (diag_cnt[i] == 4'd1) begin
                            result <= 2'd1;
                            state <= DONE_ST;
                        end
                        else begin
                            i <= i + 4'd1;
                        end
                    end
                    else begin
                        result <= 2'd2;
                        state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule