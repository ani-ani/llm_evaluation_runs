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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers for computation
    reg [15:0] result_comb;
    reg [3:0] max_bad [0:MAX_N];
    reg [3:0] left_limit [0:MAX_N];
    reg [15:0] dp [0:MAX_N];
    
    // Unpack pairs_packed into 2D array
    reg [7:0] pairs [0:MAX_PAIRS-1];
    integer i, j, k;
    reg [3:0] a, b;
    reg [15:0] sum;
    
    // Unpack pairs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_PAIRS; i = i + 1) begin
                pairs[i] <= 8'd0;
            end
        end else if (state == COMPUTE) begin
            for (i = 0; i < MAX_PAIRS; i = i + 1) begin
                pairs[i] <= pairs_packed[8*i +: 8];
            end
        end
    end
    
    // Compute max_bad
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= MAX_N; i = i + 1) begin
                max_bad[i] <= 4'd0;
            end
        end else if (state == COMPUTE) begin
            for (i = 0; i <= MAX_N; i = i + 1) begin
                max_bad[i] <= 4'd0;
            end
            for (k = 0; k < MAX_PAIRS; k = k + 1) begin
                if (k < P) begin
                    a <= pairs[k][3:0];
                    b <= pairs[k][7:4];
                    if (a != 0 && b != 0 && a <= N && b <= N && a != b) begin
                        if (a < b) begin
                            if (a > max_bad[b])
                                max_bad[b] <= a;
                        end else if (b < a) begin
                            if (b > max_bad[a])
                                max_bad[a] <= b;
                        end
                    end
                end
            end
        end
    end
    
    // Compute left_limit
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= MAX_N; i = i + 1) begin
                left_limit[i] <= 4'd0;
            end
        end else if (state == COMPUTE) begin
            for (i = 1; i <= N; i = i + 1) begin
                if (i == 1)
                    left_limit[i] <= max_bad[1] + 1;
                else begin
                    left_limit[i] <= max_bad[i] + 1;
                    if (left_limit[i-1] > left_limit[i])
                        left_limit[i] <= left_limit[i-1];
                end
            end
        end
    end
    
    // Compute dp
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= MAX_N; i = i + 1) begin
                dp[i] <= 16'd0;
            end
            result_comb <= 16'd0;
        end else if (state == COMPUTE) begin
            dp[0] <= 1;
            for (i = 1; i <= N; i = i + 1) begin
                sum <= 0;
                for (j = left_limit[i] - 1; j <= i - 1; j = j + 1) begin
                    sum <= sum + dp[j];
                end
                dp[i] <= sum % MOD;
            end
            result_comb <= dp[N];
        end
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= result_comb;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule