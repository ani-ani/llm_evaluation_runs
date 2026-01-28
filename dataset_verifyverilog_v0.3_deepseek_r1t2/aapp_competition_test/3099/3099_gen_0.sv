module spy_message_minimizer #(
    parameter N = 8,
    parameter DATA_WIDTH = N,
    parameter ADJ_WIDTH = N*N
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] enemy_mask,
    input wire [ADJ_WIDTH-1:0] adj_matrix,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_REACH = 3'd1;
    localparam [2:0] ENUMERATE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    reg [2:0] state, next_state;

    // Reachability matrix
    reg [N-1:0] reach [0:N-1];
    reg [N-1:0] safe;
    reg [N-1:0] good;

    // Enumeration variables
    reg [N-1:0] subset;
    reg [7:0] min_cost;
    reg [N-1:0] covered;
    reg [N-1:0] uncovered;

    // Loop counters
    reg [2:0] i_idx, j_idx, k_idx;
    integer r;

    // One-hot helper function
    function automatic integer popcount(input [N-1:0] val);
        integer count, i;
        begin
            count = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (val[i]) count = count + 1;
            end
            popcount = count;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            min_cost <= 8'd255;

            for (r = 0; r < N; r = r + 1) begin
                reach[r] <= 0;
            end
            safe <= 0;
            good <= 0;
            subset <= 0;
            covered <= 0;
            uncovered <= 0;
            i_idx <= 0;
            j_idx <= 0;
            k_idx <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_REACH;
                        good <= ~enemy_mask;
                        for (r = 0; r < N; r = r + 1) begin
                            reach[r] <= adj_matrix[r*N +: N];
                        end
                        i_idx <= 0;
                        j_idx <= 0;
                        k_idx <= 0;
                    end
                end

                COMPUTE_REACH: begin
                    if (reach[i_idx][k_idx] && reach[k_idx][j_idx]) begin
                        reach[i_idx][j_idx] <= 1'b1;
                    end

                    if (j_idx < N-1) j_idx <= j_idx + 1;
                    else begin
                        j_idx <= 0;
                        if (i_idx < N-1) i_idx <= i_idx + 1;
                        else begin
                            i_idx <= 0;
                            if (k_idx < N-1) k_idx <= k_idx + 1;
                            else begin
                                state <= ENUMERATE;
                                subset <= 0;
                                min_cost <= 8'd255;
                            end
                        end
                    end
                end

                ENUMERATE: begin
                    if (subset < {N{1'b1}}) begin
                        subset <= subset + 1;
                        if ((subset & ~safe) == 0) begin
                            covered <= 0;
                            for (r = 0; r < N; r = r + 1) begin
                                if (subset[r]) covered <= covered | reach[r];
                            end
                            uncovered <= good & ~covered;
                            if (popcount(subset) + popcount(uncovered) < min_cost) begin
                                min_cost <= popcount(subset) + popcount(uncovered);
                            end
                        end
                    end
                    else begin
                        result <= min_cost;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        case (state)
            COMPUTE_REACH: safe = !enemy_mask;
            default: safe = safe;
        endcase
    end

    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? COMPUTE_REACH : IDLE;
            COMPUTE_REACH: next_state = (k_idx == N-1 && i_idx == N-1 && j_idx == N-1) ? ENUMERATE : COMPUTE_REACH;
            ENUMERATE: next_state = (subset == {N{1'b1}}) ? DONE : ENUMERATE;
            DONE: next_state = (start) ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule