module drink_partition_counter #(
    parameter MAX_N = 8,
    parameter MAX_PAIRS = 8,
    parameter MOD = 1000000007
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] P,
    input wire [8*MAX_PAIRS-1:0] pairs_packed,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UNPACK = 3'd1;
    localparam [2:0] PROCESS_PAIRS = 3'd2;
    localparam [2:0] COMPUTE_LIMITS = 3'd3;
    localparam [2:0] DP_COMPUTE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] i, j, k;
    reg [3:0] a, b;
    reg [3:0] max_bad_reg [0:MAX_N];
    reg [3:0] left_limit_reg [0:MAX_N];
    reg [15:0] dp_reg [0:MAX_N];
    reg [15:0] sum;
    reg [7:0] pairs_reg [0:MAX_PAIRS-1];
    reg [7:0] temp_pair;
    reg [3:0] loop_var;
    reg [3:0] current_idx;
    reg [15:0] current_sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            a <= 4'd0;
            b <= 4'd0;
            sum <= 16'd0;
            current_sum <= 16'd0;
            current_idx <= 4'd0;
            loop_var <= 4'd0;
            temp_pair <= 8'd0;
            // Initialize arrays
            for (loop_var = 0; loop_var < MAX_N + 1; loop_var = loop_var + 1) begin
                max_bad_reg[loop_var] <= 4'd0;
                left_limit_reg[loop_var] <= 4'd0;
                dp_reg[loop_var] <= 16'd0;
            end
            // Initialize pairs array
            for (loop_var = 0; loop_var < MAX_PAIRS; loop_var = loop_var + 1) begin
                pairs_reg[loop_var] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    if (start) begin
                        state <= UNPACK;
                    end
                end

                UNPACK: begin
                    if (i < MAX_PAIRS) begin
                        pairs_reg[i] <= pairs_packed[8*i +: 8];
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        // Initialize max_bad
                        for (loop_var = 1; loop_var <= MAX_N; loop_var = loop_var + 1) begin
                            max_bad_reg[loop_var] <= 4'd0;
                        end
                        state <= PROCESS_PAIRS;
                    end
                end

                PROCESS_PAIRS: begin
                    if (k < MAX_PAIRS) begin
                        if (k < P) begin
                            temp_pair <= pairs_reg[k];
                            a <= pairs_reg[k][3:0];
                            b <= pairs_reg[k][7:4];
                        end
                        k <= k + 4'd1;
                        // Process current pair (if k < P)
                        if (k < P) begin
                            if (a != 0 && b != 0 && a <= N && b <= N && a != b) begin
                                if (a < b) begin
                                    if (a > max_bad_reg[b]) begin
                                        max_bad_reg[b] <= a;
                                    end
                                end else if (b < a) begin
                                    if (b > max_bad_reg[a]) begin
                                        max_bad_reg[a] <= b;
                                    end
                                end
                            end
                        end
                    end else begin
                        i <= 4'd1;
                        state <= COMPUTE_LIMITS;
                    end
                end

                COMPUTE_LIMITS: begin
                    if (i <= N) begin
                        if (i == 4'd1) begin
                            left_limit_reg[1] <= max_bad_reg[1] + 4'd1;
                        end else begin
                            left_limit_reg[i] <= max_bad_reg[i] + 4'd1;
                            if (left_limit_reg[i-1] > max_bad_reg[i] + 4'd1) begin
                                left_limit_reg[i] <= left_limit_reg[i-1];
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        dp_reg[0] <= 16'd1;
                        i <= 4'd1;
                        state <= DP_COMPUTE;
                    end
                end

                DP_COMPUTE: begin
                    if (i <= N) begin
                        current_sum <= 16'd0;
                        j <= left_limit_reg[i] - 4'd1;
                        if (left_limit_reg[i] <= 4'd1) begin
                            // Handle empty loop case
                            dp_reg[i] <= 16'd0;
                            i <= i + 4'd1;
                        end else begin
                            state <= DP_COMPUTE;
                            // Use a nested state or just compute sum directly
                            // We'll compute sum in a sub-loop simulation
                            if (j <= i - 4'd1) begin
                                current_sum <= current_sum + dp_reg[j];
                                j <= j + 4'd1;
                            end else begin
                                dp_reg[i] <= current_sum % MOD;
                                i <= i + 4'd1;
                            end
                        end
                    end else begin
                        result <= dp_reg[N];
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule