module coin_change(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] P_in,
    input wire [15:0] N1_in,
    input wire [15:0] N5_in,
    input wire [15:0] N10_in,
    input wire [15:0] N25_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] INIT    = 4'd1;
    localparam [3:0] CALC_1  = 4'd2;
    localparam [3:0] CALC_5  = 4'd3;
    localparam [3:0] CALC_10 = 4'd4;
    localparam [3:0] CALC_25 = 4'd5;
    localparam [3:0] CHECK   = 4'd6;
    localparam [3:0] DONE    = 4'd7;

    reg [3:0] state;
    reg [15:0] P_reg;
    reg [15:0] N1_reg;
    reg [15:0] N5_reg;
    reg [15:0] N10_reg;
    reg [15:0] N25_reg;

    // DP array - using registers for synthesis
    reg [15:0] dp [0:65535];
    reg [15:0] current_amount;
    reg [15:0] max_coins;
    reg [15:0] temp_coins;
    reg [15:0] i;
    reg [15:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            P_reg <= 16'd0;
            N1_reg <= 16'd0;
            N5_reg <= 16'd0;
            N10_reg <= 16'd0;
            N25_reg <= 16'd0;
            current_amount <= 16'd0;
            max_coins <= 16'd0;
            temp_coins <= 16'd0;
            i <= 16'd0;
            j <= 16'd0;
            // Initialize DP array to -1 (infinity)
            for (i = 0; i < 65536; i = i + 1) begin
                dp[i] <= 16'd65535;
            end
            dp[0] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        // Load inputs with saturation
                        P_reg <= P_in > 16'd65535 ? 16'd65535 : P_in;
                        N1_reg <= N1_in > 16'd65535 ? 16'd65535 : N1_in;
                        N5_reg <= N5_in > 16'd65535 ? 16'd65535 : N5_in;
                        N10_reg <= N10_in > 16'd65535 ? 16'd65535 : N10_in;
                        N25_reg <= N25_in > 16'd65535 ? 16'd65535 : N25_in;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize DP array
                    for (i = 0; i < 65536; i = i + 1) begin
                        dp[i] <= 16'd65535;
                    end
                    dp[0] <= 16'd0;
                    state <= CALC_1;
                end

                CALC_1: begin
                    // Process 1c coins
                    for (i = 0; i < P_reg; i = i + 1) begin
                        if (dp[i] != 16'd65535 && i + 1 <= P_reg && j < N1_reg) begin
                            temp_coins = dp[i] + 1;
                            if (temp_coins > dp[i + 1]) begin
                                dp[i + 1] <= temp_coins;
                            end
                        end
                    end
                    state <= CALC_5;
                end

                CALC_5: begin
                    // Process 5c coins
                    for (i = 0; i < P_reg; i = i + 1) begin
                        if (dp[i] != 16'd65535 && i + 5 <= P_reg && j < N5_reg) begin
                            temp_coins = dp[i] + 1;
                            if (temp_coins > dp[i + 5]) begin
                                dp[i + 5] <= temp_coins;
                            end
                        end
                    end
                    state <= CALC_10;
                end

                CALC_10: begin
                    // Process 10c coins
                    for (i = 0; i < P_reg; i = i + 1) begin
                        if (dp[i] != 16'd65535 && i + 10 <= P_reg && j < N10_reg) begin
                            temp_coins = dp[i] + 1;
                            if (temp_coins > dp[i + 10]) begin
                                dp[i + 10] <= temp_coins;
                            end
                        end
                    end
                    state <= CALC_25;
                end

                CALC_25: begin
                    // Process 25c coins
                    for (i = 0; i < P_reg; i = i + 1) begin
                        if (dp[i] != 16'd65535 && i + 25 <= P_reg && j < N25_reg) begin
                            temp_coins = dp[i] + 1;
                            if (temp_coins > dp[i + 25]) begin
                                dp[i + 25] <= temp_coins;
                            end
                        end
                    end
                    state <= CHECK;
                end

                CHECK: begin
                    if (dp[P_reg] != 16'd65535) begin
                        result <= dp[P_reg];
                        state <= DONE;
                    end else begin
                        result <= 16'd0;
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule