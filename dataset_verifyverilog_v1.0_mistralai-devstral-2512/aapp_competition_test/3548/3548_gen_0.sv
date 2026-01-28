module partition_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][15:0] adjacency_matrix,
    input wire [3:0] N,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    // Registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [3:0] i_reg;
    reg [3:0] j_reg;
    reg [31:0] dp [0:16];
    reg valid_segment;
    reg [3:0] k_reg;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            valid_segment <= 1'b1;
            integer idx;
            for (idx = 0; idx < 17; idx = idx + 1) begin
                dp[idx] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i_reg <= 4'd1;
                        j_reg <= 4'd0;
                        dp[0] <= 32'd1;
                        integer idx;
                        for (idx = 1; idx < 17; idx = idx + 1) begin
                            dp[idx] <= 32'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (i_reg <= N) begin
                            if (j_reg < i_reg) begin
                                // Check if segment [j_reg, i_reg-1] is valid
                                if (j_reg == i_reg - 1) begin
                                    valid_segment <= 1'b1;
                                end else begin
                                    // Check if j_reg forms a bad pair with any in (j_reg, i_reg-1]
                                    valid_segment <= 1'b1;
                                    k_reg <= j_reg + 4'd1;
                                    while (k_reg < i_reg && valid_segment) begin
                                        if (adjacency_matrix[j_reg][k_reg]) begin
                                            valid_segment <= 1'b0;
                                        end
                                        k_reg <= k_reg + 4'd1;
                                    end
                                end

                                if (valid_segment) begin
                                    dp[i_reg] <= (dp[i_reg] + dp[j_reg]) % MOD;
                                end

                                j_reg <= j_reg - 4'd1;
                            end else begin
                                i_reg <= i_reg + 4'd1;
                                j_reg <= i_reg - 4'd1;
                            end
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= dp[N];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule