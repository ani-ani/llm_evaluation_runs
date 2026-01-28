module soda_bottles(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] a [15:0],
    input wire [7:0] b [15:0],
    output reg [3:0] k,
    output reg [15:0] t,
    output reg done
);

    // State machine states
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] COMPUTE_S  = 4'd1;
    localparam [3:0] SORT       = 4'd2;
    localparam [3:0] DP_INIT    = 4'd3;
    localparam [3:0] DP_UPDATE  = 4'd4;
    localparam [3:0] FIND_RESULT = 4'd5;
    localparam [3:0] COMPLETE   = 4'd6;

    reg [3:0] state;
    reg [3:0] i_idx, j_idx, k_idx;
    reg [15:0] S;
    reg [7:0] a_sorted [15:0];
    reg [7:0] b_sorted [15:0];
    reg [15:0] max_v;
    reg dp_write_en;
    reg [15:0] dp_addr;
    reg [11:0] dp_write_data;
    reg [11:0] dp_read_data;
    reg [3:0] found_k;
    reg [15:0] found_t;
    reg [11:0] dp_table [0:4095];
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            k <= 0;
            t <= 0;
            S <= 0;
            dp_write_en <= 0;
            i_idx <= 0;
            j_idx <= 0;
            k_idx <= 0;
            found_k <= 0;
            found_t <= 0;
            dp_addr <= 0;
            dp_write_data <= 0;
            max_v <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE_S;
                        i_idx <= 0;
                        S <= 16'd0;
                    end
                end

                COMPUTE_S: begin
                    S <= S + a[i_idx];
                    if (i_idx == n - 4'd1) begin
                        i_idx <= 0;
                        state <= SORT;
                    end else begin
                        i_idx <= i_idx + 4'd1;
                    end
                end

                SORT: begin
                    if (i_idx < n - 4'd1) begin
                        if (b[i_idx] < b[i_idx + 4'd1]) begin
                            // Swap
                            a_sorted[i_idx] <= a[i_idx + 4'd1];
                            a_sorted[i_idx + 4'd1] <= a[i_idx];
                            b_sorted[i_idx] <= b[i_idx + 4'd1];
                            b_sorted[i_idx + 4'd1] <= b[i_idx];
                        end else begin
                            a_sorted[i_idx] <= a[i_idx];
                            a_sorted[i_idx + 4'd1] <= a[i_idx + 4'd1];
                            b_sorted[i_idx] <= b[i_idx];
                            b_sorted[i_idx + 4'd1] <= b[i_idx + 4'd1];
                        end
                        i_idx <= i_idx + 4'd1;
                    end else begin
                        i_idx <= 0;
                        j_idx <= 0;
                        k_idx <= 0;
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    if (k_idx < 16) begin
                        if (j_idx <= S) begin
                            dp_addr <= {k_idx[3:0], j_idx[11:0]};
                            dp_write_data <= 12'hFFF;
                            dp_write_en <= 1'b1;
                            j_idx <= j_idx + 16'd1;
                        end else begin
                            j_idx <= 0;
                            k_idx <= k_idx + 4'd1;
                        end
                    end else begin
                        dp_addr <= 16'd0;
                        dp_write_data <= 12'd0;
                        dp_write_en <= 1'b1;
                        i_idx <= 0;
                        k_idx <= 0;
                        j_idx <= S;
                        state <= DP_UPDATE;
                    end
                    dp_write_en <= 0;
                end

                DP_UPDATE: begin
                    if (i_idx < n) begin
                        if (k_idx <= 15) begin
                            if (j_idx > 0) begin
                                // Read dp[k-1][j]
                                dp_addr <= {k_idx[3:0] - 4'd1, j_idx[11:0]};
                                dp_write_en <= 0;
                                state <= DP_UPDATE;
                                if (dp_read_data != 12'hFFF) begin
                                    // Compute max_v
                                    if (j_idx + b_sorted[i_idx] > S)
                                        max_v <= S;
                                    else
                                        max_v <= j_idx + b_sorted[i_idx];
                                    // Next state will handle comparison
                                    dp_write_en <= 0;
                                    j_idx <= j_idx - 16'd1;
                                end else begin
                                    j_idx <= j_idx - 16'd1;
                                end
                            end else begin
                                j_idx <= S;
                                if (k_idx == 0)
                                    k_idx <= 15;
                                else
                                    k_idx <= k_idx - 4'd1;
                            end
                        end else begin
                            i_idx <= i_idx + 4'd1;
                            k_idx <= 0;
                            j_idx <= S;
                        end
                    end else begin
                        state <= FIND_RESULT;
                        k_idx <= 4'd1;
                        found_k <= 0;
                    end
                end

                FIND_RESULT: begin
                    if (k_idx <= n) begin
                        dp_addr <= {k_idx[3:0], S[11:0]};
                        dp_write_en <= 0;
                        if (dp_read_data != 12'hFFF) begin
                            found_k <= k_idx;
                            found_t <= S - dp_read_data;
                            state <= COMPLETE;
                        end else begin
                            k_idx <= k_idx + 4'd1;
                        end
                    end else begin
                        found_k <= n;
                        found_t <= 0;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    k <= found_k;
                    t <= found_t;
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // DP table writes (separate always block)
    always @(posedge clk) begin
        if (dp_write_en) begin
            dp_table[dp_addr] <= dp_write_data;
        end
    end

    // Read DP table (combinational)
    always @(*) begin
        dp_read_data = dp_table[dp_addr];
    end

endmodule