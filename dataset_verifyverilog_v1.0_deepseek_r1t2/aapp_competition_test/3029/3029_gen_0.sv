module tree_path #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 4,
    parameter PARENT_WIDTH = 3,
    parameter COUNT_WIDTH = 24,
    parameter MOD = 11092019
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] label_0,
    input wire [DATA_WIDTH-1:0] label_1,
    input wire [DATA_WIDTH-1:0] label_2,
    input wire [DATA_WIDTH-1:0] label_3,
    input wire [DATA_WIDTH-1:0] label_4,
    input wire [DATA_WIDTH-1:0] label_5,
    input wire [DATA_WIDTH-1:0] label_6,
    input wire [DATA_WIDTH-1:0] label_7,
    input wire [PARENT_WIDTH-1:0] parent_1,
    input wire [PARENT_WIDTH-1:0] parent_2,
    input wire [PARENT_WIDTH-1:0] parent_3,
    input wire [PARENT_WIDTH-1:0] parent_4,
    input wire [PARENT_WIDTH-1:0] parent_5,
    input wire [PARENT_WIDTH-1:0] parent_6,
    input wire [PARENT_WIDTH-1:0] parent_7,
    input wire [3:0] N,
    output reg [3:0] result_L,
    output reg [COUNT_WIDTH-1:0] result_M,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] COMPUTE_ANC = 4'd2;
    localparam [3:0] COMPUTE_DP_OUTER = 4'd3;
    localparam [3:0] COMPUTE_DP_INNER = 4'd4;
    localparam [3:0] FIND_MAX = 4'd5;
    localparam [3:0] DONE_ST = 4'd6;

    reg [3:0] state;

    // Internal storage
    reg [DATA_WIDTH-1:0] labels [0:7];
    reg [PARENT_WIDTH-1:0] parents [0:7];
    reg [7:0] anc [0:7];
    reg [3:0] dp_len [0:7];
    reg [COUNT_WIDTH-1:0] dp_cnt [0:7];

    // Counters and temporaries
    reg [3:0] i_reg, j_reg;
    reg [3:0] best_len_temp;
    reg [COUNT_WIDTH-1:0] best_cnt_temp;
    reg [3:0] global_max_len;
    reg [COUNT_WIDTH-1:0] global_total_cnt;
    integer k; // For initialization loop

    // Modulo addition function
    function [COUNT_WIDTH-1:0] mod_add;
        input [COUNT_WIDTH-1:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_L <= 4'd0;
            result_M <= {COUNT_WIDTH{1'b0}};
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            best_len_temp <= 4'd0;
            best_cnt_temp <= {COUNT_WIDTH{1'b0}};
            global_max_len <= 4'd0;
            global_total_cnt <= {COUNT_WIDTH{1'b0}};
            
            // Initialize arrays
            for (k = 0; k < 8; k = k + 1) begin
                labels[k] <= {DATA_WIDTH{1'b0}};
                parents[k] <= {PARENT_WIDTH{1'b0}};
                anc[k] <= 8'd0;
                dp_len[k] <= 4'd0;
                dp_cnt[k] <= {COUNT_WIDTH{1'b0}};
            end
        
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Store labels
                    labels[0] <= label_0;
                    labels[1] <= label_1;
                    labels[2] <= label_2;
                    labels[3] <= label_3;
                    labels[4] <= label_4;
                    labels[5] <= label_5;
                    labels[6] <= label_6;
                    labels[7] <= label_7;
                    
                    // Store parents (node 0 has no parent)
                    parents[0] <= {PARENT_WIDTH{1'b0}};
                    parents[1] <= parent_1;
                    parents[2] <= parent_2;
                    parents[3] <= parent_3;
                    parents[4] <= parent_4;
                    parents[5] <= parent_5;
                    parents[6] <= parent_6;
                    parents[7] <= parent_7;
                    
                    i_reg <= 4'd0;
                    state <= COMPUTE_ANC;
                end

                COMPUTE_ANC: begin
                    if (i_reg < N) begin
                        if (i_reg == 4'd0) begin
                            anc[i_reg] <= 8'b00000001;
                        end else begin
                            anc[i_reg] <= anc[parents[i_reg]] | (8'd1 << i_reg);
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        i_reg <= 4'd0;
                        state <= COMPUTE_DP_OUTER;
                    end
                end

                COMPUTE_DP_OUTER: begin
                    if (i_reg < N) begin
                        best_len_temp <= 4'd0;
                        best_cnt_temp <= {COUNT_WIDTH{1'b0}};
                        j_reg <= 4'd0;
                        state <= COMPUTE_DP_INNER;
                    end else begin
                        i_reg <= 4'd0;
                        global_max_len <= 4'd0;
                        global_total_cnt <= {COUNT_WIDTH{1'b0}};
                        state <= FIND_MAX;
                    end
                end

                COMPUTE_DP_INNER: begin
                    if (j_reg < i_reg) begin
                        if (anc[i_reg][j_reg] && (labels[j_reg] <= labels[i_reg])) begin
                            if (dp_len[j_reg] > best_len_temp) begin
                                best_len_temp <= dp_len[j_reg];
                                best_cnt_temp <= dp_cnt[j_reg];
                            end else if (dp_len[j_reg] == best_len_temp) begin
                                best_cnt_temp <= mod_add(best_cnt_temp, dp_cnt[j_reg]);
                            end
                        end
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        if (best_len_temp == 4'd0) begin
                            dp_len[i_reg] <= 4'd1;
                            dp_cnt[i_reg] <= 24'd1;
                        end else begin
                            dp_len[i_reg] <= best_len_temp + 4'd1;
                            dp_cnt[i_reg] <= best_cnt_temp;
                        end
                        i_reg <= i_reg + 4'd1;
                        state <= COMPUTE_DP_OUTER;
                    end
                end

                FIND_MAX: begin
                    if (i_reg < N) begin
                        if (dp_len[i_reg] > global_max_len) begin
                            global_max_len <= dp_len[i_reg];
                            global_total_cnt <= dp_cnt[i_reg];
                        end else if (dp_len[i_reg] == global_max_len) begin
                            global_total_cnt <= mod_add(global_total_cnt, dp_cnt[i_reg]);
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        result_L <= global_max_len;
                        result_M <= global_total_cnt;
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule