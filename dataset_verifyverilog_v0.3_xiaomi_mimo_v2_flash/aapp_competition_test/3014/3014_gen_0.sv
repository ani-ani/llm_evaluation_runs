module CycleBreaker #(
    parameter N_MAX = 8,
    parameter M_MAX = 16
)(
    input clk, rst_n, start,
    input [3:0] n,
    input [4:0] m,
    input [3:0] src [M_MAX-1:0],
    input [3:0] dst [M_MAX-1:0],
    output reg [4:0] r,
    output reg [3:0] remove_list [M_MAX-1:0],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] FIND_MAX = 4'd2;
    localparam [3:0] APPEND = 4'd3;
    localparam [3:0] UPDATE = 4'd4;
    localparam [3:0] CHECK_DONE = 4'd5;
    localparam [3:0] COMPUTE_REMOVAL = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] i, j, k; // Loop counters
    reg [3:0] max_idx;
    reg [3:0] active_count;
    reg [4:0] current_r;
    reg [3:0] pos_reg [N_MAX-1:0]; // Position of each vertex
    reg active [N_MAX-1:0]; // Active/inactive flag
    reg [3:0] outdegree [N_MAX-1:0]; // Outdegree of active vertices
    reg [M_MAX-1:0] is_backward; // Flag for backward edges
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            r <= 5'd0;
            // Initialize arrays
            for (i = 0; i < N_MAX; i = i + 1) begin
                pos_reg[i] <= 4'd0;
                active[i] <= 1'b0;
                outdegree[i] <= 4'd0;
            end
            for (i = 0; i < M_MAX; i = i + 1) begin
                remove_list[i] <= 4'd0;
                is_backward[i] <= 1'b0;
            end
            max_idx <= 4'd0;
            active_count <= 4'd0;
            current_r <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    r <= 5'd0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Reset all arrays and counters
                    for (i = 0; i < N_MAX; i = i + 1) begin
                        pos_reg[i] <= 4'd0;
                        active[i] <= (i < n) ? 1'b1 : 1'b0;
                        outdegree[i] <= 4'd0;
                    end
                    for (i = 0; i < M_MAX; i = i + 1) begin
                        remove_list[i] <= 4'd0;
                        is_backward[i] <= 1'b0;
                    end
                    current_r <= 5'd0;
                    max_idx <= 4'd0;
                    active_count <= n;
                    i <= 4'd0;
                    state <= FIND_MAX;
                end

                FIND_MAX: begin
                    // Find vertex with max outdegree
                    if (i < n) begin
                        if (active[i]) begin
                            if (i == 4'd0) begin
                                max_idx <= 4'd0;
                                outdegree[4'd0] <= 4'd0;
                            end else begin
                                outdegree[i] <= 4'd0;
                            end
                        end
                        i <= i + 4'd1;
                        state <= FIND_MAX;
                    end else begin
                        i <= 4'd0;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Calculate outdegree for active vertices
                    if (i < m && i < M_MAX) begin
                        if (active[src[i]] && active[dst[i]]) begin
                            outdegree[src[i]] <= outdegree[src[i]] + 4'd1;
                        end
                        i <= i + 4'd1;
                        state <= UPDATE;
                    end else begin
                        i <= 4'd0;
                        state <= APPEND;
                    end
                end

                APPEND: begin
                    // Check for max among active vertices
                    if (i < n) begin
                        if (active[i]) begin
                            if (outdegree[i] > outdegree[max_idx]) begin
                                max_idx <= i;
                            end
                        end
                        i <= i + 4'd1;
                        state <= APPEND;
                    end else begin
                        // Append max_idx to ordering
                        pos_reg[max_idx] <= current_r;
                        active[max_idx] <= 1'b0;
                        active_count <= active_count - 4'd1;
                        current_r <= current_r + 5'd1;
                        i <= 4'd0;
                        state <= CHECK_DONE;
                    end
                end

                CHECK_DONE: begin
                    if (active_count > 4'd0) begin
                        i <= 4'd0;
                        state <= FIND_MAX;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= COMPUTE_REMOVAL;
                    end
                end

                COMPUTE_REMOVAL: begin
                    // Check all edges for backward condition
                    if (j < m && j < M_MAX) begin
                        if (pos_reg[src[j]] > pos_reg[dst[j]]) begin
                            is_backward[j] <= 1'b1;
                        end
                        j <= j + 4'd1;
                        state <= COMPUTE_REMOVAL;
                    end else begin
                        i <= 4'd0;
                        r <= 5'd0;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Build remove list (1-based indices)
                    if (i < m && i < M_MAX) begin
                        if (is_backward[i]) begin
                            remove_list[r] <= i[3:0] + 4'd1; // 1-based
                            r <= r + 5'd1;
                        end
                        i <= i + 4'd1;
                        state <= OUTPUT;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            cycle_count <= cycle_count + 5'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule