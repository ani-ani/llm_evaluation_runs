module h_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,
    input wire [5:0] m,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    // Registers for DP
    reg [1:0] state;
    reg [5:0] i, j, k, l;
    reg [6:0] dp1 [0:50][0:50];  // dp1[i][j]
    reg [31:0] dp2 [0:50];        // dp2[k] for current j
    reg [31:0] temp_sum;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd52;

    integer row_idx, col_idx, clear_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
            // Initialize dp1 to 0
            for (row_idx = 0; row_idx < 51; row_idx = row_idx + 1) begin
                for (col_idx = 0; col_idx < 51; col_idx = col_idx + 1) begin
                    dp1[row_idx][col_idx] <= 7'd0;
                end
            end
            for (clear_idx = 0; clear_idx < 51; clear_idx = clear_idx + 1) begin
                dp2[clear_idx] <= 32'd0;
            end
            i <= 6'd0;
            j <= 6'd0;
            k <= 6'd0;
            l <= 6'd0;
            temp_sum <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        if (n < 1 || n > 50 || m < 1 || m > 50) begin
                            result <= 32'd0;
                            done <= 1'b1;
                        end else begin
                            state <= LOAD;
                            i <= 6'd0;
                            j <= 6'd0;
                        end
                    end
                end

                LOAD: begin
                    // Load a[1..n] = 1..n, b[1..n] = 1..n
                    // Initialize DP base cases
                    // dp1[i][j] = 0 for i < j
                    // dp1[i][j] = 1 for i = j
                    // dp2[k] = 1 for k = 1
                    if (i == 6'd0 && j == 6'd0) begin
                        dp2[1] <= 32'd1;
                    end
                    
                    // Fill dp1
                    if (i <= n) begin
                        if (j < i) begin
                            dp1[i][j] <= 7'd0;
                            j <= j + 6'd1;
                        end else if (j == i) begin
                            dp1[i][j] <= 7'd1;
                            j <= 6'd0;
                            i <= i + 6'd1;
                        end
                    end else begin
                        i <= 6'd1;
                        j <= 2'd2;
                        k <= 6'd1;
                        l <= 6'd1;
                        temp_sum <= 32'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Compute dp1[i][j] for i >= 2, j >= 2, i >= j
                    if (i <= n) begin
                        if (j <= i && j >= 2) begin
                            // Find k in [j-1, i-1] with min a[k] (which is k)
                            // Since a[k] = k, the minimum k is j-1
                            // So we need dp1[i-1][j-1] + dp2[j-1]
                            // dp1[i][j] <= dp1[i-1][j-1] + dp2[j-1]
                            if (j <= n) begin
                                dp1[i][j] <= dp1[i-1][j-1] + dp2[j-1];
                            end else begin
                                dp1[i][j] <= dp1[i-1][j-1];
                            end
                            j <= j + 6'd1;
                        end else begin
                            // Update dp2 for current j-1 using k from 1 to i
                            if (k <= i) begin
                                if (l <= i) begin
                                    // dp2[j-1] += dp1[k][l] * dp1[l][j-1]
                                    if (l <= n && j-1 <= n && k <= n) begin
                                        temp_sum <= temp_sum + (dp1[k][l] * dp1[l][j-1]);
                                    end
                                    l <= l + 6'd1;
                                end else begin
                                    dp2[j-1] <= temp_sum;
                                    temp_sum <= 32'd0;
                                    k <= k + 6'd1;
                                    l <= 6'd1;
                                end
                            end else begin
                                // Reset for next j
                                k <= 6'd1;
                                l <= 6'd1;
                                if (j <= n) begin
                                    i <= 6'd1;
                                    j <= j + 6'd1;
                                end else begin
                                    // All computations done
                                    state <= FINISH;
                                end
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= dp1[n][m];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule