module coin_count(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] b [0:9],
    input wire [15:0] a [0:8],
    input wire signed [31:0] m_scaled,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [8:0] MAX_SIZE = 9'd512;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] PROCESS_STRIDE = 3'd2;
    localparam [2:0] PROCESS_PREFIX = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State and control signals
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Arrays for DP
    reg [31:0] d [0:511];
    reg [31:0] td [0:511];
    reg [8:0] L;
    reg [8:0] current_coin;
    reg [8:0] i, j, k;
    reg [15:0] t;
    reg [15:0] stride;
    reg [15:0] window_start;
    reg [31:0] accumulator;
    reg [31:0] temp_value;

    // Initialize arrays
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            L <= 9'd0;
            current_coin <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            t <= 16'd0;
            stride <= 16'd0;
            window_start <= 16'd0;
            accumulator <= 32'd0;
            temp_value <= 32'd0;
            for (idx = 0; idx < 512; idx = idx + 1) begin
                d[idx] <= 32'd0;
                td[idx] <= 32'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SETUP;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SETUP: begin
                    // Initialize d array
                    d[0] <= 32'd1;
                    L <= 9'd0;
                    current_coin <= 8'd0;
                    next_state <= PROCESS_STRIDE;
                end

                PROCESS_STRIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_coin < 9'd10) begin
                        if (a[current_coin] != 16'd1) begin
                            // Compute t = m_scaled % a[current_coin]
                            t <= m_scaled[31:0] % a[current_coin];
                            if (L < t) begin
                                // No solution
                                result <= 32'd0;
                                next_state <= DONE_STATE;
                            end else begin
                                // Update m_scaled = m_scaled / a[current_coin]
                                m_scaled <= m_scaled[31:0] / a[current_coin];
                                stride <= a[current_coin];
                                j <= 8'd0;
                                next_state <= PROCESS_STRIDE;
                            end
                        end else begin
                            // No stride operation needed
                            next_state <= PROCESS_PREFIX;
                        end
                    end else begin
                        next_state <= PROCESS_PREFIX;
                    end
                end

                PROCESS_PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_coin < 9'd10) begin
                        // Perform prefix sum with sliding window
                        accumulator <= 32'd0;
                        window_start <= 16'd0;
                        j <= 8'd0;
                        next_state <= PROCESS_PREFIX;
                    end else begin
                        // Final result
                        if (m_scaled[31:0] <= L) begin
                            result <= d[m_scaled[31:0]];
                        end else begin
                            result <= 32'd0;
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Stride operation logic
    always @(posedge clk) begin
        if (state == PROCESS_STRIDE && current_coin < 9'd10 && a[current_coin] != 16'd1) begin
            if (j <= (L - t) / stride) begin
                d[j] <= d[t + j * stride];
                j <= j + 8'd1;
            end else begin
                L <= (L - t) / stride;
                current_coin <= current_coin + 8'd1;
                next_state <= PROCESS_PREFIX;
            end
        end
    end

    // Prefix sum with sliding window logic
    always @(posedge clk) begin
        if (state == PROCESS_PREFIX && current_coin < 9'd10) begin
            if (j <= L) begin
                if (j < b[current_coin]) begin
                    td[j] <= d[j];
                end else begin
                    temp_value <= d[j - b[current_coin]];
                    accumulator <= (accumulator + d[j]) % MOD;
                    td[j] <= accumulator;
                    if (j >= b[current_coin]) begin
                        accumulator <= (accumulator - temp_value + MOD) % MOD;
                    end
                end
                j <= j + 8'd1;
            end else begin
                // Swap d and td arrays
                for (idx = 0; idx < 512; idx = idx + 1) begin
                    d[idx] <= td[idx];
                end
                current_coin <= current_coin + 8'd1;
                next_state <= PROCESS_STRIDE;
            end
        end
    end

endmodule