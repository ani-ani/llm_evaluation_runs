module heap_subset #(
    parameter NODES = 8,
    parameter VAL_WIDTH = 8,
    parameter IDX_WIDTH = 3,
    parameter RESULT_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [VAL_WIDTH-1:0] val [0:NODES-1],
    input wire [IDX_WIDTH-1:0] parent [0:NODES-1],
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ANCESTOR = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DP_COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Ancestor matrix
    reg [NODES-1:0] anc [0:NODES-1];
    reg [IDX_WIDTH-1:0] i_reg, j_reg;

    // Sorting network
    reg [VAL_WIDTH-1:0] sorted_val [0:NODES-1];
    reg [IDX_WIDTH-1:0] sorted_idx [0:NODES-1];

    // DP table
    reg [RESULT_WIDTH-1:0] dp [0:NODES-1];
    reg [IDX_WIDTH-1:0] k_reg;

    // Temporary registers
    reg [RESULT_WIDTH-1:0] max_result;
    reg [IDX_WIDTH-1:0] m_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            k_reg <= 3'd0;
            m_reg <= 3'd0;
            max_result <= 4'd0;

            // Initialize ancestor matrix
            integer i, j;
            for (i = 0; i < NODES; i = i + 1) begin
                for (j = 0; j < NODES; j = j + 1) begin
                    anc[i][j] <= 1'b0;
                end
            end

            // Initialize DP table
            for (i = 0; i < NODES; i = i + 1) begin
                dp[i] <= 4'd0;
            end

            // Initialize sorted arrays
            for (i = 0; i < NODES; i = i + 1) begin
                sorted_val[i] <= 8'd0;
                sorted_idx[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_ANCESTOR;
                        i_reg <= 3'd0;
                        j_reg <= 3'd0;
                    end
                end

                COMPUTE_ANCESTOR: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute ancestor matrix
                    if (i_reg == j_reg || parent[j_reg] == i_reg) begin
                        anc[i_reg][j_reg] <= 1'b1;
                    end else begin
                        integer p;
                        reg found;
                        found = 1'b0;
                        p = parent[j_reg];
                        while (p != 3'd0 && !found) begin
                            if (anc[i_reg][p]) begin
                                found = 1'b1;
                            end
                            p = parent[p];
                        end
                        if (found) begin
                            anc[i_reg][j_reg] <= 1'b1;
                        end
                    end

                    // Update indices
                    if (j_reg == 3'd7) begin
                        if (i_reg == 3'd7) begin
                            state <= SORT;
                            // Initialize sorted arrays
                            integer i;
                            for (i = 0; i < NODES; i = i + 1) begin
                                sorted_val[i] <= val[i];
                                sorted_idx[i] <= i;
                            end
                        end else begin
                            i_reg <= i_reg + 3'd1;
                            j_reg <= 3'd0;
                        end
                    end else begin
                        j_reg <= j_reg + 3'd1;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Bitonic sort network for 8 elements
                    // Stage 1
                    if (cycle_count == 8'd1) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 2
                    else if (cycle_count == 8'd2) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            sorted_val[0] <= val[2];
                            sorted_val[2] <= val[0];
                            sorted_idx[0] <= 2;
                            sorted_idx[2] <= 0;
                        end
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            sorted_val[4] <= val[6];
                            sorted_val[6] <= val[4];
                            sorted_idx[4] <= 6;
                            sorted_idx[6] <= 4;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 3
                    else if (cycle_count == 8'd3) begin
                        if (sorted_val[0] < sorted_val[4]) begin
                            sorted_val[0] <= val[4];
                            sorted_val[4] <= val[0];
                            sorted_idx[0] <= 4;
                            sorted_idx[4] <= 0;
                        end
                        if (sorted_val[1] < sorted_val[5]) begin
                            sorted_val[1] <= val[5];
                            sorted_val[5] <= val[1];
                            sorted_idx[1] <= 5;
                            sorted_idx[5] <= 1;
                        end
                        if (sorted_val[2] < sorted_val[6]) begin
                            sorted_val[2] <= val[6];
                            sorted_val[6] <= val[2];
                            sorted_idx[2] <= 6;
                            sorted_idx[6] <= 2;
                        end
                        if (sorted_val[3] < sorted_val[7]) begin
                            sorted_val[3] <= val[7];
                            sorted_val[7] <= val[3];
                            sorted_idx[3] <= 7;
                            sorted_idx[7] <= 3;
                        end
                    end
                    // Stage 4
                    else if (cycle_count == 8'd4) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            sorted_val[1] <= val[2];
                            sorted_val[2] <= val[1];
                            sorted_idx[1] <= 2;
                            sorted_idx[2] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            sorted_val[5] <= val[6];
                            sorted_val[6] <= val[5];
                            sorted_idx[5] <= 6;
                            sorted_idx[6] <= 5;
                        end
                    end
                    // Stage 5
                    else if (cycle_count == 8'd5) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 6
                    else if (cycle_count == 8'd6) begin
                        if (sorted_val[3] < sorted_val[4]) begin
                            sorted_val[3] <= val[4];
                            sorted_val[4] <= val[3];
                            sorted_idx[3] <= 4;
                            sorted_idx[4] <= 3;
                        end
                    end
                    // Stage 7
                    else if (cycle_count == 8'd7) begin
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 8
                    else if (cycle_count == 8'd8) begin
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 9
                    else if (cycle_count == 8'd9) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            sorted_val[0] <= val[2];
                            sorted_val[2] <= val[0];
                            sorted_idx[0] <= 2;
                            sorted_idx[2] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            sorted_val[4] <= val[6];
                            sorted_val[6] <= val[4];
                            sorted_idx[4] <= 6;
                            sorted_idx[6] <= 4;
                        end
                    end
                    // Stage 10
                    else if (cycle_count == 8'd10) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            sorted_val[1] <= val[2];
                            sorted_val[2] <= val[1];
                            sorted_idx[1] <= 2;
                            sorted_idx[2] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            sorted_val[5] <= val[6];
                            sorted_val[6] <= val[5];
                            sorted_idx[5] <= 6;
                            sorted_idx[6] <= 5;
                        end
                    end
                    // Stage 11
                    else if (cycle_count == 8'd11) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                    end
                    // Stage 12
                    else if (cycle_count == 8'd12) begin
                        if (sorted_val[3] < sorted_val[4]) begin
                            sorted_val[3] <= val[4];
                            sorted_val[4] <= val[3];
                            sorted_idx[3] <= 4;
                            sorted_idx[4] <= 3;
                        end
                    end
                    // Stage 13
                    else if (cycle_count == 8'd13) begin
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 14
                    else if (cycle_count == 8'd14) begin
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 15
                    else if (cycle_count == 8'd15) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            sorted_val[0] <= val[2];
                            sorted_val[2] <= val[0];
                            sorted_idx[0] <= 2;
                            sorted_idx[2] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            sorted_val[4] <= val[6];
                            sorted_val[6] <= val[4];
                            sorted_idx[4] <= 6;
                            sorted_idx[6] <= 4;
                        end
                    end
                    // Stage 16
                    else if (cycle_count == 8'd16) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            sorted_val[1] <= val[2];
                            sorted_val[2] <= val[1];
                            sorted_idx[1] <= 2;
                            sorted_idx[2] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            sorted_val[5] <= val[6];
                            sorted_val[6] <= val[5];
                            sorted_idx[5] <= 6;
                            sorted_idx[6] <= 5;
                        end
                    end
                    // Stage 17
                    else if (cycle_count == 8'd17) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                    end
                    // Stage 18
                    else if (cycle_count == 8'd18) begin
                        if (sorted_val[3] < sorted_val[4]) begin
                            sorted_val[3] <= val[4];
                            sorted_val[4] <= val[3];
                            sorted_idx[3] <= 4;
                            sorted_idx[4] <= 3;
                        end
                    end
                    // Stage 19
                    else if (cycle_count == 8'd19) begin
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 20
                    else if (cycle_count == 8'd20) begin
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 21
                    else if (cycle_count == 8'd21) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            sorted_val[0] <= val[2];
                            sorted_val[2] <= val[0];
                            sorted_idx[0] <= 2;
                            sorted_idx[2] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            sorted_val[4] <= val[6];
                            sorted_val[6] <= val[4];
                            sorted_idx[4] <= 6;
                            sorted_idx[6] <= 4;
                        end
                    end
                    // Stage 22
                    else if (cycle_count == 8'd22) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            sorted_val[1] <= val[2];
                            sorted_val[2] <= val[1];
                            sorted_idx[1] <= 2;
                            sorted_idx[2] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            sorted_val[5] <= val[6];
                            sorted_val[6] <= val[5];
                            sorted_idx[5] <= 6;
                            sorted_idx[6] <= 5;
                        end
                    end
                    // Stage 23
                    else if (cycle_count == 8'd23) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                    end
                    // Stage 24
                    else if (cycle_count == 8'd24) begin
                        if (sorted_val[3] < sorted_val[4]) begin
                            sorted_val[3] <= val[4];
                            sorted_val[4] <= val[3];
                            sorted_idx[3] <= 4;
                            sorted_idx[4] <= 3;
                        end
                    end
                    // Stage 25
                    else if (cycle_count == 8'd25) begin
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 26
                    else if (cycle_count == 8'd26) begin
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                    end
                    // Stage 27
                    else if (cycle_count == 8'd27) begin
                        if (sorted_val[0] < sorted_val[2]) begin
                            sorted_val[0] <= val[2];
                            sorted_val[2] <= val[0];
                            sorted_idx[0] <= 2;
                            sorted_idx[2] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[6]) begin
                            sorted_val[4] <= val[6];
                            sorted_val[6] <= val[4];
                            sorted_idx[4] <= 6;
                            sorted_idx[6] <= 4;
                        end
                    end
                    // Stage 28
                    else if (cycle_count == 8'd28) begin
                        if (sorted_val[1] < sorted_val[2]) begin
                            sorted_val[1] <= val[2];
                            sorted_val[2] <= val[1];
                            sorted_idx[1] <= 2;
                            sorted_idx[2] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[6]) begin
                            sorted_val[5] <= val[6];
                            sorted_val[6] <= val[5];
                            sorted_idx[5] <= 6;
                            sorted_idx[6] <= 5;
                        end
                    end
                    // Stage 29
                    else if (cycle_count == 8'd29) begin
                        if (sorted_val[0] < sorted_val[1]) begin
                            sorted_val[0] <= val[1];
                            sorted_val[1] <= val[0];
                            sorted_idx[0] <= 1;
                            sorted_idx[1] <= 0;
                        end
                        if (sorted_val[4] < sorted_val[5]) begin
                            sorted_val[4] <= val[5];
                            sorted_val[5] <= val[4];
                            sorted_idx[4] <= 5;
                            sorted_idx[5] <= 4;
                        end
                    end
                    // Stage 30
                    else if (cycle_count == 8'd30) begin
                        if (sorted_val[3] < sorted_val[4]) begin
                            sorted_val[3] <= val[4];
                            sorted_val[4] <= val[3];
                            sorted_idx[3] <= 4;
                            sorted_idx[4] <= 3;
                        end
                    end
                    // Stage 31
                    else if (cycle_count == 8'd31) begin
                        if (sorted_val[1] < sorted_val[3]) begin
                            sorted_val[1] <= val[3];
                            sorted_val[3] <= val[1];
                            sorted_idx[1] <= 3;
                            sorted_idx[3] <= 1;
                        end
                        if (sorted_val[5] < sorted_val[7]) begin
                            sorted_val[5] <= val[7];
                            sorted_val[7] <= val[5];
                            sorted_idx[5] <= 7;
                            sorted_idx[7] <= 5;
                        end
                    end
                    // Stage 32
                    else if (cycle_count == 8'd32) begin
                        if (sorted_val[2] < sorted_val[3]) begin
                            sorted_val[2] <= val[3];
                            sorted_val[3] <= val[2];
                            sorted_idx[2] <= 3;
                            sorted_idx[3] <= 2;
                        end
                        if (sorted_val[6] < sorted_val[7]) begin
                            sorted_val[6] <= val[7];
                            sorted_val[7] <= val[6];
                            sorted_idx[6] <= 7;
                            sorted_idx[7] <= 6;
                        end
                        state <= DP_COMPUTE;
                        k_reg <= 3'd0;
                    end
                end

                DP_COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute DP for current node
                    integer j;
                    reg [RESULT_WIDTH-1:0] max_dp;
                    max_dp = 4'd0;

                    for (j = 0; j < NODES; j = j + 1) begin
                        if (anc[sorted_idx[j]][sorted_idx[k_reg]] && sorted_val[j] > sorted_val[k_reg]) begin
                            if (dp[j] > max_dp) begin
                                max_dp = dp[j];
                            end
                        end
                    end

                    dp[k_reg] <= max_dp + 4'd1;

                    // Update max result
                    if (dp[k_reg] > max_result) begin
                        max_result = dp[k_reg];
                    end

                    // Update index
                    if (k_reg == 3'd7) begin
                        state <= FINISH;
                    end else begin
                        k_reg <= k_reg + 3'd1;
                    end
                end

                FINISH: begin
                    result <= max_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule