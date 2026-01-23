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
    // Labels for nodes 0 to 7
    input wire [DATA_WIDTH-1:0] label_0,
    input wire [DATA_WIDTH-1:0] label_1,
    input wire [DATA_WIDTH-1:0] label_2,
    input wire [DATA_WIDTH-1:0] label_3,
    input wire [DATA_WIDTH-1:0] label_4,
    input wire [DATA_WIDTH-1:0] label_5,
    input wire [DATA_WIDTH-1:0] label_6,
    input wire [DATA_WIDTH-1:0] label_7,
    // Parents for nodes 1 to 7 (parent index < child index)
    input wire [PARENT_WIDTH-1:0] parent_1,
    input wire [PARENT_WIDTH-1:0] parent_2,
    input wire [PARENT_WIDTH-1:0] parent_3,
    input wire [PARENT_WIDTH-1:0] parent_4,
    input wire [PARENT_WIDTH-1:0] parent_5,
    input wire [PARENT_WIDTH-1:0] parent_6,
    input wire [PARENT_WIDTH-1:0] parent_7,
    // Number of valid nodes (1 to 8)
    input wire [3:0] N,
    // Outputs
    output reg [3:0] result_L,
    output reg [COUNT_WIDTH-1:0] result_M,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE_ANC = 3'd2;
    localparam [2:0] COMPUTE_DP_OUTER = 3'd3;
    localparam [2:0] COMPUTE_DP_INNER = 3'd4;
    localparam [2:0] FIND_MAX = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // Internal storage
    reg [DATA_WIDTH-1:0] labels [0:MAX_N-1];
    reg [PARENT_WIDTH-1:0] parents [0:MAX_N-1];
    reg [MAX_N-1:0] anc [0:MAX_N-1]; // ancestry bit masks
    reg [DATA_WIDTH-1:0] dp_len [0:MAX_N-1];
    reg [COUNT_WIDTH-1:0] dp_cnt [0:MAX_N-1];

    // Counters and temporaries
    reg [3:0] i_reg, j_reg;
    reg [DATA_WIDTH-1:0] best_len_temp;
    reg [COUNT_WIDTH-1:0] best_cnt_temp;
    reg [DATA_WIDTH-1:0] global_max_len;
    reg [COUNT_WIDTH-1:0] global_total_cnt;

    // Helper: modulo addition
    function [COUNT_WIDTH-1:0] mod_add;
        input [COUNT_WIDTH-1:0] a, b;
        begin
            mod_add = a + b;
            if (mod_add >= MOD) mod_add = mod_add - MOD;
        end
    endfunction

    // Sequential state transition and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_L <= 4'd0;
            result_M <= 24'd0;
            // Initialize all registers
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            best_len_temp <= 4'd0;
            best_cnt_temp <= 24'd0;
            global_max_len <= 4'd0;
            global_total_cnt <= 24'd0;
            // Initialize arrays
            integer i;
            for (i = 0; i < MAX_N; i = i + 1) begin
                labels[i] <= 4'd0;
                parents[i] <= 3'd0;
                anc[i] <= 8'd0;
                dp_len[i] <= 4'd0;
                dp_cnt[i] <= 24'd0;
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
                    // Load labels and parents
                    labels[0] <= label_0;
                    labels[1] <= label_1;
                    labels[2] <= label_2;
                    labels[3] <= label_3;
                    labels[4] <= label_4;
                    labels[5] <= label_5;
                    labels[6] <= label_6;
                    labels[7] <= label_7;
                    parents[0] <= 3'd0; // root has no parent
                    parents[1] <= parent_1;
                    parents[2] <= parent_2;
                    parents[3] <= parent_3;
                    parents[4] <= parent_4;
                    parents[5] <= parent_5;
                    parents[6] <= parent_6;
                    parents[7] <= parent_7;
                    // Initialize counters
                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                    best_len_temp <= 4'd0;
                    best_cnt_temp <= 24'd0;
                    global_max_len <= 4'd0;
                    global_total_cnt <= 24'd0;
                    // Initialize anc and dp arrays
                    integer i;
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        anc[i] <= 8'd0;
                        dp_len[i] <= 4'd0;
                        dp_cnt[i] <= 24'd0;
                    end
                    state <= COMPUTE_ANC;
                end

                COMPUTE_ANC: begin
                    // Compute anc[i] for current i_reg
                    if (i_reg < N) begin
                        if (i_reg == 0) begin
                            anc[i_reg] <= (1 << i_reg);
                        end else begin
                            // anc[i] = anc[parent] | (1<<i)
                            anc[i_reg] <= anc[parents[i_reg]] | (1 << i_reg);
                        end
                        i_reg <= i_reg + 4'd1;
                    end else begin
                        // Done with anc computation
                        i_reg <= 4'd0;
                        state <= COMPUTE_DP_OUTER;
                    end
                end

                COMPUTE_DP_OUTER: begin
                    // Initialize for current node i_reg
                    if (i_reg < N) begin
                        best_len_temp <= 4'd0;
                        best_cnt_temp <= 24'd0;
                        j_reg <= 4'd0;
                        state <= COMPUTE_DP_INNER;
                    end else begin
                        // Done with DP computation, move to find max
                        i_reg <= 4'd0;
                        state <= FIND_MAX;
                    end
                end

                COMPUTE_DP_INNER: begin
                    // Check ancestor j for current i_reg
                    if (j_reg < i_reg) begin
                        // Check if j is ancestor of i and label[j] <= label[i]
                        if (anc[i_reg][j_reg] && (labels[j_reg] <= labels[i_reg])) begin
                            // Compare dp_len[j] with best_len_temp
                            if (dp_len[j_reg] > best_len_temp) begin
                                best_len_temp <= dp_len[j_reg];
                                best_cnt_temp <= dp_cnt[j_reg];
                            end else if (dp_len[j_reg] == best_len_temp) begin
                                best_cnt_temp <= mod_add(best_cnt_temp, dp_cnt[j_reg]);
                            end
                        end
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        // No more j, set dp_len and dp_cnt for i_reg
                        if (best_len_temp == 4'd0) begin
                            dp_len[i_reg] <= 4'd1;
                            dp_cnt[i_reg] <= 24'd1;
                        end else begin
                            dp_len[i_reg] <= best_len_temp + 4'd1;
                            dp_cnt[i_reg] <= best_cnt_temp;
                        end
                        // Move to next i
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
                        // Done, set outputs
                        result_L <= global_max_len;
                        result_M <= global_total_cnt;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule