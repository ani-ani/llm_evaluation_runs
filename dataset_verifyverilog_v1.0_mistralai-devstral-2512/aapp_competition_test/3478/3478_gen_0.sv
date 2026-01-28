module graph_partition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [255:0] edges,
    output reg valid,
    output reg [15:0] arya_mask,
    output reg [15:0] sansa_mask,
    output reg [15:0] other_mask,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_A = 4'd1;
    localparam [3:0] COMPUTE_B = 4'd2;
    localparam [3:0] COMPUTE_REMAINING = 4'd3;
    localparam [3:0] VERIFY = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Arya's clique (must include node 1 - bit 0)
    reg [15:0] arya_temp;
    // Sansa's clique (must include node 2 - bit 1)
    reg [15:0] sansa_temp;
    // Remaining nodes
    reg [15:0] remaining_temp;

    // Helper function to check if a node is in a clique
    function check_clique_member;
        input [15:0] clique;
        input [3:0] node;
        input [255:0] edge_matrix;
        integer i;
        reg [15:0] neighbor;
        begin
            // Check if node is connected to all nodes in clique
            for (i = 0; i < 16; i = i + 1) begin
                if (clique[i]) begin
                    neighbor = edge_matrix[(node << 4) + i];
                    if (!neighbor) begin
                        check_clique_member = 0;
                        return;
                    end
                end
            end
            check_clique_member = 1;
        end
    endfunction

    // Helper function to check if a clique is valid
    function check_clique_valid;
        input [15:0] clique;
        input [255:0] edge_matrix;
        integer i, j;
        begin
            // Check all pairs in clique are connected
            for (i = 0; i < 16; i = i + 1) begin
                if (clique[i]) begin
                    for (j = i + 1; j < 16; j = j + 1) begin
                        if (clique[j]) begin
                            if (!edge_matrix[(i << 4) + j]) begin
                                check_clique_valid = 0;
                                return;
                            end
                        end
                    end
                end
            end
            check_clique_valid = 1;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            arya_mask <= 16'd0;
            sansa_mask <= 16'd0;
            other_mask <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            arya_temp <= 16'd0;
            sansa_temp <= 16'd0;
            remaining_temp <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_A;
                    end
                end

                COMPUTE_A: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize Arya's clique with node 1 (bit 0)
                    arya_temp <= 16'd1;
                    // Expand Arya's clique
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n && i != 0 && check_clique_member(arya_temp, i, edges)) begin
                            arya_temp[i] <= 1'b1;
                        end
                    end
                    state <= COMPUTE_B;
                end

                COMPUTE_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize Sansa's clique with node 2 (bit 1)
                    sansa_temp <= 16'd2;
                    // Expand Sansa's clique (cannot include Arya's nodes)
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n && i != 1 && !arya_temp[i] && check_clique_member(sansa_temp, i, edges)) begin
                            sansa_temp[i] <= 1'b1;
                        end
                    end
                    state <= COMPUTE_REMAINING;
                end

                COMPUTE_REMAINING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute remaining nodes
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n && !arya_temp[i] && !sansa_temp[i]) begin
                            remaining_temp[i] <= 1'b1;
                        end else begin
                            remaining_temp[i] <= 1'b0;
                        end
                    end
                    state <= VERIFY;
                end

                VERIFY: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if node 1 and 2 are directly connected
                    if (edges[1]) begin
                        valid <= 1'b0;
                    end else begin
                        // Verify all cliques
                        if (check_clique_valid(arya_temp, edges) &&
                            check_clique_valid(sansa_temp, edges) &&
                            check_clique_valid(remaining_temp, edges)) begin
                            valid <= 1'b1;
                            arya_mask <= arya_temp;
                            sansa_mask <= sansa_temp;
                            other_mask <= remaining_temp;
                        end else begin
                            valid <= 1'b0;
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end
endmodule