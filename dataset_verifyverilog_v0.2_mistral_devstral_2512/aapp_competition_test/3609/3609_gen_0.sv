module tree_assignment (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [4:0] edge_u [14:0],
    input [4:0] edge_v [14:0],
    output reg [14:0] l_mask,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        CHECKING,
        DONE
    } state_t;

    // State registers
    state_t state;
    reg [3:0] edge_idx; // Current edge index (0-15)
    reg [14:0] l_mask_reg; // Left tree mask
    reg [14:0] r_mask_reg; // Right tree mask
    reg [7:0] l_reach; // Reachable nodes in Left tree (bitmask)
    reg [7:0] r_reach; // Reachable nodes in Right tree (bitmask)
    reg [3:0] backtrack_idx; // Backtracking index

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_idx <= 0;
            l_mask_reg <= 0;
            r_mask_reg <= 0;
            l_reach <= 0;
            r_reach <= 0;
            backtrack_idx <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        edge_idx <= 0;
                        l_mask_reg <= 0;
                        r_mask_reg <= 0;
                        l_reach <= 1 << 0; // Node 1 is reachable in Left tree
                        r_reach <= 1 << (n - 1); // Node n is reachable in Right tree
                        backtrack_idx <= 0;
                        valid <= 0;
                        done <= 0;
                    end
                end
                PROCESSING: begin
                    if (edge_idx == 15) begin
                        state <= CHECKING;
                    end else begin
                        // Try assigning current edge to Left tree
                        if (edge_u[edge_idx] < edge_v[edge_idx]) begin
                            if (l_reach[edge_u[edge_idx] - 1]) begin
                                // Assign to Left tree
                                l_mask_reg[edge_idx] <= 1;
                                l_reach[edge_v[edge_idx] - 1] <= 1;
                                edge_idx <= edge_idx + 1;
                            end else begin
                                // Try assigning to Right tree
                                if (r_reach[edge_v[edge_idx] - 1]) begin
                                    r_mask_reg[edge_idx] <= 1;
                                    r_reach[edge_u[edge_idx] - 1] <= 1;
                                    edge_idx <= edge_idx + 1;
                                end else begin
                                    // Backtrack
                                    if (edge_idx > 0) begin
                                        edge_idx <= edge_idx - 1;
                                        if (l_mask_reg[edge_idx]) begin
                                            l_mask_reg[edge_idx] <= 0;
                                            l_reach[edge_v[edge_idx] - 1] <= 0;
                                        end else begin
                                            r_mask_reg[edge_idx] <= 0;
                                            r_reach[edge_u[edge_idx] - 1] <= 0;
                                        end
                                    end else begin
                                        state <= DONE;
                                    end
                                end
                            end
                        end else begin
                            // Try assigning to Right tree
                            if (r_reach[edge_v[edge_idx] - 1]) begin
                                r_mask_reg[edge_idx] <= 1;
                                r_reach[edge_u[edge_idx] - 1] <= 1;
                                edge_idx <= edge_idx + 1;
                            end else begin
                                // Backtrack
                                if (edge_idx > 0) begin
                                    edge_idx <= edge_idx - 1;
                                    if (l_mask_reg[edge_idx]) begin
                                        l_mask_reg[edge_idx] <= 0;
                                        l_reach[edge_v[edge_idx] - 1] <= 0;
                                    end else begin
                                        r_mask_reg[edge_idx] <= 0;
                                        r_reach[edge_u[edge_idx] - 1] <= 0;
                                    end
                                end else begin
                                    state <= DONE;
                                end
                            end
                        end
                    end
                end
                CHECKING: begin
                    // Check if all nodes are reachable in both trees
                    reg [7:0] all_reach = (1 << n) - 1;
                    if ((l_reach == all_reach) && (r_reach == all_reach)) begin
                        valid <= 1;
                    end else begin
                        valid <= 0;
                    end
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Output assignments
    always @(posedge clk) begin
        l_mask <= l_mask_reg;
    end

endmodule