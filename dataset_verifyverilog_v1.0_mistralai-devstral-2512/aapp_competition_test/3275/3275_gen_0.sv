module painting_ways(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a [0:15],
    input wire [15:0] b [0:15],
    input wire [3:0] C,
    input wire [6:0] Q,
    input wire update_en,
    input wire [3:0] update_idx,
    input wire [15:0] new_a,
    input wire [15:0] new_b,
    output reg [15:0] result,
    output reg done
);

    localparam [15:0] MOD = 16'd10007;
    localparam [3:0] N = 16'd16;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    reg [15:0] a_reg [0:15];
    reg [15:0] b_reg [0:15];
    reg [15:0] dp [0:16];
    reg [3:0] client_idx;
    reg [3:0] k_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            client_idx <= 4'd0;
            k_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                a_reg[i] <= 16'd0;
                b_reg[i] <= 16'd0;
            end
            for (i = 0; i < 17; i = i + 1) begin
                dp[i] <= 16'd0;
            end
            dp[0] <= 16'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        client_idx <= 4'd0;
                        k_idx <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            a_reg[i] <= a[i];
                            b_reg[i] <= b[i];
                        end
                        dp[0] <= 16'd1;
                        for (i = 1; i < 17; i = i + 1) begin
                            dp[i] <= 16'd0;
                        end
                    end else if (update_en) begin
                        state <= UPDATE;
                        client_idx <= 4'd0;
                        k_idx <= 4'd0;
                        a_reg[update_idx] <= new_a;
                        b_reg[update_idx] <= new_b;
                        dp[0] <= 16'd1;
                        for (i = 1; i < 17; i = i + 1) begin
                            dp[i] <= 16'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (client_idx < N) begin
                        if (k_idx == 0) begin
                            dp[0] <= (dp[0] * ((a_reg[client_idx] + b_reg[client_idx]) % MOD)) % MOD;
                            k_idx <= k_idx + 4'd1;
                        end else if (k_idx <= client_idx) begin
                            dp[k_idx] <= (dp[k_idx] * ((a_reg[client_idx] + b_reg[client_idx]) % MOD) + dp[k_idx - 1]) % MOD;
                            k_idx <= k_idx + 4'd1;
                        end else begin
                            client_idx <= client_idx + 4'd1;
                            k_idx <= 4'd0;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (client_idx < N) begin
                        if (k_idx == 0) begin
                            dp[0] <= (dp[0] * ((a_reg[client_idx] + b_reg[client_idx]) % MOD)) % MOD;
                            k_idx <= k_idx + 4'd1;
                        end else if (k_idx <= client_idx) begin
                            dp[k_idx] <= (dp[k_idx] * ((a_reg[client_idx] + b_reg[client_idx]) % MOD) + dp[k_idx - 1]) % MOD;
                            k_idx <= k_idx + 4'd1;
                        end else begin
                            client_idx <= client_idx + 4'd1;
                            k_idx <= 4'd0;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= 16'd0;
                    for (i = C; i < 17; i = i + 1) begin
                        result <= (result + dp[i]) % MOD;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule