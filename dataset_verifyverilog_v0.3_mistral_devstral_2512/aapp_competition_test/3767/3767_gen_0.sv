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

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_S = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DP_INIT = 3'd3;
    localparam [2:0] DP_UPDATE = 3'd4;
    localparam [2:0] FIND_RESULT = 3'd5;
    localparam [2:0] COMPLETE = 3'd6;

    reg [2:0] state;
    reg [3:0] i, j;
    reg [3:0] k_idx;
    reg [15:0] S;
    reg [7:0] a_sorted [15:0];
    reg [7:0] b_sorted [15:0];
    reg [15:0] dp_addr;
    reg [11:0] dp_write_data;
    reg [11:0] dp_read_data;
    reg dp_write_en;
    reg [15:0] max_v;
    reg [11:0] best_sum;
    reg [3:0] found_k;
    reg [15:0] found_t;

    reg [11:0] dp_table [0:4095];

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            k <= 4'd0;
            t <= 16'd0;
            S <= 16'd0;
            dp_write_en <= 1'b0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                a_sorted[idx] <= 8'd0;
                b_sorted[idx] <= 8'd0;
            end
            for (idx = 0; idx < 4096; idx = idx + 1) begin
                dp_table[idx] <= 12'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_S;
                        i <= 4'd0;
                        S <= 16'd0;
                    end
                end
                
                COMPUTE_S: begin
                    S <= S + a[i];
                    if (i == n - 1) begin
                        i <= 4'd0;
                        state <= SORT;
                    end else begin
                        i <= i + 1;
                    end
                end
                
                SORT: begin
                    if (i < n - 1) begin
                        if (b[i] < b[i + 1]) begin
                            a_sorted[i] <= a[i + 1];
                            a_sorted[i + 1] <= a[i];
                            b_sorted[i] <= b[i + 1];
                            b_sorted[i + 1] <= b[i];
                        end else begin
                            a_sorted[i] <= a[i];
                            a_sorted[i + 1] <= a[i + 1];
                            b_sorted[i] <= b[i];
                            b_sorted[i + 1] <= b[i + 1];
                        end
                        i <= i + 1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k_idx <= 4'd0;
                        state <= DP_INIT;
                    end
                end
                
                DP_INIT: begin
                    if (k_idx < 16) begin
                        if (j <= S) begin
                            dp_table[{k_idx[3:0], j[11:0]}] <= 12'hFFF;
                            j <= j + 1;
                        end else begin
                            j <= 4'd0;
                            k_idx <= k_idx + 1;
                        end
                    end else begin
                        dp_table[16'd0] <= 12'd0;
                        i <= 4'd0;
                        k_idx <= 4'd0;
                        j <= S;
                        state <= DP_UPDATE;
                    end
                end
                
                DP_UPDATE: begin
                    if (i < n) begin
                        if (k_idx > 0) begin
                            if (j > 0) begin
                                if (dp_table[{k_idx[3:0] - 1'd1, j[11:0]}] != 12'hFFF) begin
                                    max_v <= (j + b_sorted[i] > S) ? S : (j + b_sorted[i]);
                                    if (dp_table[{k_idx[3:0], max_v[11:0]}] < (dp_table[{k_idx[3:0] - 1'd1, j[11:0]}] + a_sorted[i])) begin
                                        dp_table[{k_idx[3:0], max_v[11:0]}] <= dp_table[{k_idx[3:0] - 1'd1, j[11:0]}] + a_sorted[i];
                                    end
                                end
                                j <= j - 1;
                            end else begin
                                j <= S;
                                k_idx <= k_idx - 1;
                            end
                        end else begin
                            i <= i + 1;
                            k_idx <= 15;
                            j <= S;
                        end
                    end else begin
                        state <= FIND_RESULT;
                        k_idx <= 4'd1;
                        found_k <= 4'd0;
                    end
                end
                
                FIND_RESULT: begin
                    if (k_idx <= n) begin
                        if (dp_table[{k_idx[3:0], S[11:0]}] != 12'hFFF) begin
                            found_k <= k_idx;
                            found_t <= S - dp_table[{k_idx[3:0], S[11:0]}];
                            state <= COMPLETE;
                        end else begin
                            k_idx <= k_idx + 1;
                        end
                    end else begin
                        found_k <= n;
                        found_t <= 16'd0;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    k <= found_k;
                    t <= found_t;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule