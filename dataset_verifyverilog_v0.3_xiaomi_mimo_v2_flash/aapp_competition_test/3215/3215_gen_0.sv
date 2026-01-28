module shuffle_number #(
    parameter N = 8,
    parameter DATA_WIDTH = 4,
    parameter RESULT_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] perm_0,
    input wire [DATA_WIDTH-1:0] perm_1,
    input wire [DATA_WIDTH-1:0] perm_2,
    input wire [DATA_WIDTH-1:0] perm_3,
    input wire [DATA_WIDTH-1:0] perm_4,
    input wire [DATA_WIDTH-1:0] perm_5,
    input wire [DATA_WIDTH-1:0] perm_6,
    input wire [DATA_WIDTH-1:0] perm_7,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // Helper to access perm array from individual inputs
    wire [DATA_WIDTH-1:0] perm [0:N-1];
    assign perm[0] = perm_0;
    assign perm[1] = perm_1;
    assign perm[2] = perm_2;
    assign perm[3] = perm_3;
    assign perm[4] = perm_4;
    assign perm[5] = perm_5;
    assign perm[6] = perm_6;
    assign perm[7] = perm_7;

    // Internal arrays - packed for better compatibility
    reg [2:0] pos [0:N-1];
    reg [0:0] inc [0:N-2];
    reg [2:0] f [0:N-1];
    reg [2:0] f_next [0:N-1];

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_POS_START = 4'd1;
    localparam [3:0] INIT_POS_LOOP = 4'd2;
    localparam [3:0] INIT_INC_START = 4'd3;
    localparam [3:0] INIT_INC_LOOP = 4'd4;
    localparam [3:0] DP_START = 4'd5;
    localparam [3:0] DP_INIT = 4'd6;
    localparam [3:0] DP_LEN_LOOP = 4'd7;
    localparam [3:0] DP_L_LOOP = 4'd8;
    localparam [3:0] DP_M_LOOP = 4'd9;
    localparam [3:0] DP_UPDATE = 4'd10;
    localparam [3:0] DP_ROW_START = 4'd11;
    localparam [3:0] DP_ROW_LOOP = 4'd12;
    localparam [3:0] DONE = 4'd13;

    reg [3:0] state;
    reg [2:0] len_cnt;
    reg [2:0] l_cnt;
    reg [2:0] m_cnt;
    reg [2:0] best;
    reg [2:0] temp;
    reg [2:0] i;
    reg [2:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {RESULT_WIDTH{1'b0}};
            len_cnt <= 3'd0;
            l_cnt <= 3'd0;
            m_cnt <= 3'd0;
            best <= 3'd0;
            temp <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            for (i = 0; i < N; i = i + 1) begin
                pos[i] <= 3'd0;
                f[i] <= 3'd0;
                f_next[i] <= 3'd0;
            end
            for (i = 0; i < N-1; i = i + 1) begin
                inc[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_POS_START;
                    end
                end

                INIT_POS_START: begin
                    l_cnt <= 3'd0;
                    state <= INIT_POS_LOOP;
                end

                INIT_POS_LOOP: begin
                    if (l_cnt < N) begin
                        // pos[ perm[l_cnt] - 1 ] = l_cnt
                        // Need to find index where perm[index] = l_cnt + 1
                        if (perm[l_cnt] == l_cnt + 1) begin
                            pos[l_cnt] <= l_cnt;
                        end
                        l_cnt <= l_cnt + 3'd1;
                    end else begin
                        state <= INIT_INC_START;
                    end
                end

                INIT_INC_START: begin
                    l_cnt <= 3'd0;
                    state <= INIT_INC_LOOP;
                end

                INIT_INC_LOOP: begin
                    if (l_cnt < N-1) begin
                        if (pos[l_cnt] < pos[l_cnt+1])
                            inc[l_cnt] <= 1'b1;
                        else
                            inc[l_cnt] <= 1'b0;
                        l_cnt <= l_cnt + 3'd1;
                    end else begin
                        state <= DP_START;
                    end
                end

                DP_START: begin
                    l_cnt <= 3'd0;
                    state <= DP_INIT;
                end

                DP_INIT: begin
                    if (l_cnt < N) begin
                        f[l_cnt] <= 3'd0;
                        f_next[l_cnt] <= 3'd0;
                        l_cnt <= l_cnt + 3'd1;
                    end else begin
                        len_cnt <= 3'd2;
                        state <= DP_LEN_LOOP;
                    end
                end

                DP_LEN_LOOP: begin
                    if (len_cnt <= N) begin
                        l_cnt <= 3'd0;
                        state <= DP_L_LOOP;
                    end else begin
                        result <= f[0];
                        state <= DONE;
                    end
                end

                DP_L_LOOP: begin
                    if (l_cnt <= N - len_cnt) begin
                        best <= 3'd7;
                        m_cnt <= l_cnt;
                        state <= DP_M_LOOP;
                    end else begin
                        // Update f with f_next
                        for (j = 0; j < N; j = j + 1) begin
                            f[j] <= f_next[j];
                        end
                        len_cnt <= len_cnt + 3'd1;
                        state <= DP_LEN_LOOP;
                    end
                end

                DP_M_LOOP: begin
                    if (m_cnt <= l_cnt + len_cnt - 3'd2) begin
                        if (f[l_cnt] > f[m_cnt+1])
                            temp <= f[l_cnt];
                        else
                            temp <= f[m_cnt+1];
                        state <= DP_UPDATE;
                    end else begin
                        f_next[l_cnt] <= best;
                        l_cnt <= l_cnt + 3'd1;
                        state <= DP_L_LOOP;
                    end
                end

                DP_UPDATE: begin
                    if (temp + 3'd1 < best)
                        best <= temp + 3'd1;
                    m_cnt <= m_cnt + 3'd1;
                    state <= DP_M_LOOP;
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule