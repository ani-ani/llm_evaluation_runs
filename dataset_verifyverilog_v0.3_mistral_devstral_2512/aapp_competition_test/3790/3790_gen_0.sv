module longest_non_decreasing_subsequence(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] T,
    input [7:0] base_array_0, base_array_1, base_array_2, base_array_3,
    input [7:0] base_array_4, base_array_5, base_array_6, base_array_7,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EXPAND = 3'd1;
    localparam [2:0] INIT_DP = 3'd2;
    localparam [2:0] DP_OUTER = 3'd3;
    localparam [2:0] DP_INNER = 3'd4;
    localparam [2:0] FIND_MAX = 3'd5;
    localparam [2:0] COMPLETE = 3'd6;

    // Internal registers
    reg [7:0] arr [0:63];
    reg [7:0] dp [0:63];
    reg [7:0] L;
    reg [7:0] rep;
    reg [7:0] base_idx;
    reg [7:0] base_addr;
    reg [7:0] i_index, j_index;
    reg [7:0] max_val;
    reg [2:0] state;

    // Multiplexer for base array input
    wire [7:0] base_val;
    assign base_val = (base_idx == 0) ? base_array_0 :
                      (base_idx == 1) ? base_array_1 :
                      (base_idx == 2) ? base_array_2 :
                      (base_idx == 3) ? base_array_3 :
                      (base_idx == 4) ? base_array_4 :
                      (base_idx == 5) ? base_array_5 :
                      (base_idx == 6) ? base_array_6 :
                      base_array_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            L <= 8'd0;
            rep <= 8'd0;
            base_idx <= 8'd0;
            base_addr <= 8'd0;
            i_index <= 8'd0;
            j_index <= 8'd0;
            max_val <= 8'd0;
            integer k;
            for (k = 0; k < 64; k = k + 1) begin
                arr[k] <= 8'd0;
                dp[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        L <= n * T;
                        rep <= 8'd0;
                        base_idx <= 8'd0;
                        base_addr <= 8'd0;
                        state <= EXPAND;
                    end
                end

                EXPAND: begin
                    if (rep < T) begin
                        if (base_idx < n) begin
                            arr[base_addr + base_idx] <= base_val;
                            base_idx <= base_idx + 8'd1;
                        end else begin
                            base_idx <= 8'd0;
                            rep <= rep + 8'd1;
                            base_addr <= base_addr + n;
                        end
                    end else begin
                        state <= INIT_DP;
                        i_index <= 8'd0;
                    end
                end

                INIT_DP: begin
                    if (i_index < L) begin
                        dp[i_index] <= 8'd1;
                        i_index <= i_index + 8'd1;
                    end else begin
                        state <= DP_OUTER;
                        i_index <= 8'd0;
                        j_index <= 8'd0;
                    end
                end

                DP_OUTER: begin
                    if (i_index < L) begin
                        state <= DP_INNER;
                        j_index <= 8'd0;
                    end else begin
                        state <= FIND_MAX;
                        i_index <= 8'd0;
                        max_val <= dp[0];
                    end
                end

                DP_INNER: begin
                    if (j_index < i_index) begin
                        if (arr[j_index] <= arr[i_index]) begin
                            if (dp[j_index] + 8'd1 > dp[i_index]) begin
                                dp[i_index] <= dp[j_index] + 8'd1;
                            end
                        end
                        j_index <= j_index + 8'd1;
                    end else begin
                        state <= DP_OUTER;
                        i_index <= i_index + 8'd1;
                    end
                end

                FIND_MAX: begin
                    if (i_index < L) begin
                        if (dp[i_index] > max_val) begin
                            max_val <= dp[i_index];
                        end
                        i_index <= i_index + 8'd1;
                    end else begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= max_val;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule