module anatoly_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] pre_obs [7:0],
    input wire [7:0] in_obs [7:0],
    input wire [7:0] post_obs [7:0],
    input wire [3:0] n,
    output reg valid,
    output reg [1:0] call_config [5:0],
    output reg [7:0] tree_pre [7:0],
    output reg [7:0] tree_in [7:0],
    output reg [7:0] tree_post [7:0],
    output reg done
);
    parameter MAX_N = 8;
    reg [3:0] state;
    localparam IDLE = 0;
    localparam PREPARE_CONFIG = 1;
    localparam CHECK_CONFIG = 2;
    localparam CHECK_TREES = 3;
    localparam FOUND_SOLUTION = 4;
    localparam FINISHED = 5;
    reg [9:0] perm_idx;
    reg [3:0] root_idx;
    reg [3:0] left_size;
    reg [7:0] calc_pre [MAX_N-1:0];
    reg [7:0] calc_in [MAX_N-1:0];
    reg [7:0] calc_post [MAX_N-1:0];
    reg [7:0] obs_pre [MAX_N-1:0];
    reg [7:0] obs_in [MAX_N-1:0];
    reg [7:0] obs_post [MAX_N-1:0];
    reg [3:0] current_n;
    reg [1:0] current_calls [5:0];
    integer i, j, k;
    reg match;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            perm_idx <= 0;
            root_idx <= 0;
            left_size <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            if (i < n) begin
                                obs_pre[i] <= pre_obs[i];
                                obs_in[i] <= in_obs[i];
                                obs_post[i] <= post_obs[i];
                            end else begin
                                obs_pre[i] <= 8'h0;
                                obs_in[i] <= 8'h0;
                                obs_post[i] <= 8'h0;
                            end
                        end
                        current_n <= n;
                        perm_idx <= 0;
                        root_idx <= 0;
                        left_size <= 0;
                        state <= PREPARE_CONFIG;
                        valid <= 0;
                        done <= 0;
                    end
                end
                PREPARE_CONFIG: begin
                    if (perm_idx < 720) begin
                        state <= CHECK_CONFIG;
                    end else begin
                        state <= FINISHED;
                    end
                end
                CHECK_CONFIG: begin
                    root_idx <= 0;
                    left_size <= 0;
                    state <= CHECK_TREES;
                end
                CHECK_TREES: begin
                    if (root_idx < current_n) begin
                        if (left_size <= root_idx) begin
                            if (check_consistency(current_calls, root_idx, left_size)) begin
                                valid <= 1;
                                call_config <= current_calls;
                                tree_pre <= generate_pre(root_idx, left_size);
                                tree_in <= generate_in(root_idx, left_size);
                                tree_post <= generate_post(root_idx, left_size);
                                state <= FOUND_SOLUTION;
                            end else begin
                                if (left_size < root_idx) begin
                                    left_size <= left_size + 1;
                                end else begin
                                    left_size <= 0;
                                    root_idx <= root_idx + 1;
                                end
                            end
                        end else begin
                            left_size <= 0;
                            root_idx <= root_idx + 1;
                        end
                    end else begin
                        perm_idx <= perm_idx + 1;
                        state <= PREPARE_CONFIG;
                    end
                end
                FOUND_SOLUTION: begin
                    done <= 1;
                    state <= FINISHED;
                end
                FINISHED: begin
                end
            endcase
        end
    end
    function automatic logic check_consistency(input [1:0] c [5:0], input [3:0] r, input [3:0] ls);
        check_consistency = 1'b1;
    endfunction
    function automatic [7:0] [MAX_N-1:0] generate_pre(input [3:0] r, input [3:0] ls);
        integer idx = 0;
        generate_pre = 0;
    endfunction
    function automatic [7:0] [MAX_N-1:0] generate_in(input [3:0] r, input [3:0] ls);
        generate_in = 0;
    endfunction
    function automatic [7:0] [MAX_N-1:0] generate_post(input [3:0] r, input [3:0] ls);
        generate_post = 0;
    endfunction
endmodule