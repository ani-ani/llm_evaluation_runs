module partition_divider (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [5:0] c,
    input [5:0] year [0:15],
    input [3:0] a [0:15],
    input [3:0] b [0:15],
    output reg [5:0] result_year,
    output reg result_valid,
    output reg result_impossible,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam PROCESS_EDGES = 3'b010;
    localparam CHECK_SUBSET = 3'b011;
    localparam NEXT_YEAR = 3'b100;
    localparam DONE_SUCCESS = 3'b101;
    localparam DONE_FAIL = 3'b110;

    // Registers
    reg [2:0] state;
    reg [5:0] Y;
    reg [5:0] limit_size;
    reg [3:0] edge_idx;
    reg [3:0] parent [0:15];
    reg [3:0] size [0:15];
    reg flag_A [0:15];
    reg flag_B [0:15];
    reg [15:0] reachable;
    reg [3:0] component_sizes [0:15];
    reg [3:0] num_components;
    reg [3:0] comp_idx;
    reg conflict_found;

    // Temporary variables
    reg [3:0] u, v;
    reg [3:0] root_u, root_v;
    reg [3:0] temp_u, temp_v;

    // Helper function to find root
    function [3:0] find_root(input [3:0] node);
        begin
            find_root = node;
            if (parent[find_root] != find_root) find_root = parent[find_root];
            if (parent[find_root] != find_root) find_root = parent[find_root];
            if (parent[find_root] != find_root) find_root = parent[find_root];
            if (parent[find_root] != find_root) find_root = parent[find_root];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result_valid <= 0;
            result_impossible <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (n == 0 || n > 16) begin
                            state <= DONE_FAIL;
                        end else begin
                            limit_size <= (2 * n) / 3;
                            Y <= 0;
                            edge_idx <= 0;
                            state <= SETUP;
                        end
                    end
                end

                SETUP: begin
                    if (edge_idx < n) begin
                        parent[edge_idx] <= edge_idx;
                        size[edge_idx] <= 1;
                        flag_A[edge_idx] <= 0;
                        flag_B[edge_idx] <= 0;
                        edge_idx <= edge_idx + 1;
                    end else begin
                        edge_idx <= 0;
                        state <= PROCESS_EDGES;
                    end
                end

                PROCESS_EDGES: begin
                    if (edge_idx < c && edge_idx < 16) begin
                        u = a[edge_idx];
                        v = b[edge_idx];
                        root_u = find_root(u);
                        root_v = find_root(v);
                        if (root_u != root_v) begin
                            if (size[root_u] < size[root_v]) begin
                                parent[root_u] <= root_v;
                                size[root_v] <= size[root_u] + size[root_v];
                                flag_A[root_v] <= flag_A[root_v] | flag_A[root_u];
                                flag_B[root_v] <= flag_B[root_v] | flag_B[root_u];
                                if (year[edge_idx] < Y) begin
                                    flag_A[root_v] <= 1'b1;
                                    if (flag_B[root_v]) conflict_found <= 1;
                                end else begin
                                    flag_B[root_v] <= 1'b1;
                                    if (flag_A[root_v]) conflict_found <= 1;
                                end
                            end else begin
                                parent[root_v] <= root_u;
                                size[root_u] <= size[root_u] + size[root_v];
                                flag_A[root_u] <= flag_A[root_u] | flag_A[root_v];
                                flag_B[root_u] <= flag_B[root_u] | flag_B[root_v];
                                if (year[edge_idx] < Y) begin
                                    flag_A[root_u] <= 1'b1;
                                    if (flag_B[root_u]) conflict_found <= 1;
                                end else begin
                                    flag_B[root_u] <= 1'b1;
                                    if (flag_A[root_u]) conflict_found <= 1;
                                end
                            end
                        end else begin
                            if (year[edge_idx] < Y) begin
                                flag_A[root_u] <= 1'b1;
                                if (flag_B[root_u]) conflict_found <= 1;
                            end else begin
                                flag_B[root_u] <= 1'b1;
                                if (flag_A[root_u]) conflict_found <= 1;
                            end
                        end
                        edge_idx <= edge_idx + 1;
                    end else begin
                        if (conflict_found) begin
                            state <= NEXT_YEAR;
                        end else begin
                            state <= CHECK_SUBSET;
                        end
                    end
                end

                CHECK_SUBSET: begin
                    if (comp_idx < num_components) begin
                        // Update reachable sums
                        // This is a simplified version for illustration
                        // In practice, you would use a more efficient subset sum algorithm
                        reachable <= reachable | (reachable << component_sizes[comp_idx]);
                        comp_idx <= comp_idx + 1;
                    end else begin
                        // Check if any reachable sum is within the valid range
                        if (reachable & ((1 << limit_size) - 1) & ~((1 << (n - limit_size)) - 1))) begin
                            result_valid <= 1;
                            result_year <= Y;
                        end else begin
                            result_impossible <= 1;
                        end
                        state <= NEXT_YEAR;
                    end
                end

                NEXT_YEAR: begin
                    if (Y < 59) begin
                        Y <= Y + 1;
                        edge_idx <= 0;
                        conflict_found <= 0;
                        state <= SETUP;
                    end else begin
                        state <= DONE_FAIL;
                    end
                end

                DONE_SUCCESS: begin
                    done <= 1;
                end

                DONE_FAIL: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule