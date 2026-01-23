module combinatorial (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [3:0] K,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [22:0] MOD = 23'd1000007;

    // States
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SETUP   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // State machine
    reg [1:0] state;

    // Counters
    reg [2:0] i;      // 0 to N (max 8)
    reg [3:0] j;      // 0 to K (max 8)
    reg [3:0] c;      // 0 to min(M, j) (max 8)

    // DP arrays (size K+1, max 9)
    reg [31:0] dp_prev [0:8];
    reg [31:0] dp_curr [0:8];

    // Temporary sum
    reg [31:0] sum;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize counters
            i <= 3'd0;
            j <= 4'd0;
            c <= 4'd0;

            // Initialize DP arrays
            integer k;
            for (k = 0; k < 9; k = k + 1) begin
                dp_prev[k] <= 32'd0;
                dp_curr[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SETUP;
                    end
                end

                SETUP: begin
                    // Initialize dp_prev[0] = 1, others = 0
                    dp_prev[0] <= 32'd1;
                    integer k;
                    for (k = 1; k < 9; k = k + 1) begin
                        dp_prev[k] <= 32'd0;
                    end

                    // Initialize counters
                    i <= 3'd0;
                    j <= 4'd0;
                    c <= 4'd0;

                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (i < N) begin
                        if (j <= K) begin
                            if (c <= M && c <= j) begin
                                // Accumulate sum
                                if (c == 0) begin
                                    sum <= dp_prev[j - c];
                                end else begin
                                    sum <= (sum + dp_prev[j - c]) % MOD;
                                end
                                c <= c + 4'd1;
                            end else begin
                                // Store result
                                dp_curr[j] <= sum;
                                c <= 4'd0;
                                j <= j + 4'd1;
                            end
                        end else begin
                            // Copy dp_curr to dp_prev
                            integer k;
                            for (k = 0; k < 9; k = k + 1) begin
                                dp_prev[k] <= dp_curr[k];
                            end

                            // Reset j and increment i
                            j <= 4'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        // Final result
                        result <= dp_prev[K];
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule