module k_multihedgehog_verifier(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [0:15][0:15] adj_matrix,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] COMPUTE   = 4'd1;
    localparam [3:0] CHECK     = 4'd2;
    localparam [3:0] FAIL      = 4'd3;
    localparam [3:0] SUCCESS   = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [3:0] iter;
    reg [3:0] remaining_nodes;
    reg [3:0] leaf_count;
    reg [3:0] common_parent;
    reg [3:0] parent_degree;
    reg [3:0] i, j;
    reg [3:0] current_node;
    reg [3:0] degree [0:15];
    reg [3:0] removed [0:15];
    reg [3:0] temp_degree;
    reg [3:0] temp_parent;
    reg [3:0] temp_common_parent;
    reg [3:0] temp_leaf_count;
    reg [3:0] temp_remaining;
    reg [3:0] temp_valid;
    reg [3:0] temp_parent_degree;
    reg [3:0] temp_i;
    reg [3:0] temp_j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            iter <= 4'd0;
            remaining_nodes <= 4'd0;
            leaf_count <= 4'd0;
            common_parent <= 4'd0;
            parent_degree <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_node <= 4'd0;
            for (temp_i = 0; temp_i < 16; temp_i = temp_i + 1) begin
                degree[temp_i] <= 4'd0;
                removed[temp_i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        iter <= 4'd0;
                        remaining_nodes <= n;
                        for (temp_i = 0; temp_i < 16; temp_i = temp_i + 1) begin
                            removed[temp_i] <= 1'b0;
                            degree[temp_i] <= 4'd0;
                            for (temp_j = 0; temp_j < 16; temp_j = temp_j + 1) begin
                                if (adj_matrix[temp_i][temp_j] && temp_i != temp_j) begin
                                    degree[temp_i] <= degree[temp_i] + 4'd1;
                                end
                            end
                        end
                    end
                end

                COMPUTE: begin
                    if (iter == k) begin
                        state <= CHECK;
                    end else begin
                        leaf_count <= 4'd0;
                        common_parent <= 4'd16;
                        parent_degree <= 4'd0;
                        temp_common_parent <= 4'd16;
                        temp_leaf_count <= 4'd0;
                        temp_parent_degree <= 4'd0;
                        temp_valid <= 1'b1;

                        for (temp_i = 0; temp_i < 16; temp_i = temp_i + 1) begin
                            if (!removed[temp_i] && degree[temp_i] == 4'd1) begin
                                temp_leaf_count <= temp_leaf_count + 4'd1;
                                for (temp_j = 0; temp_j < 16; temp_j = temp_j + 1) begin
                                    if (adj_matrix[temp_i][temp_j] && !removed[temp_j]) begin
                                        if (temp_common_parent == 4'd16) begin
                                            temp_common_parent <= temp_j;
                                        end else if (temp_common_parent != temp_j) begin
                                            temp_valid <= 1'b0;
                                        end
                                    end
                                end
                            end
                        end

                        if (!temp_valid || temp_leaf_count == 4'd0) begin
                            state <= FAIL;
                        end else begin
                            for (temp_j = 0; temp_j < 16; temp_j = temp_j + 1) begin
                                if (adj_matrix[temp_common_parent][temp_j] && !removed[temp_j]) begin
                                    temp_parent_degree <= temp_parent_degree + 4'd1;
                                end
                            end

                            if (temp_parent_degree < 4'd3) begin
                                state <= FAIL;
                            end else begin
                                leaf_count <= temp_leaf_count;
                                common_parent <= temp_common_parent;
                                parent_degree <= temp_parent_degree;
                                state <= CHECK;
                            end
                        end
                    end
                end

                CHECK: begin
                    if (iter == k) begin
                        temp_remaining <= 4'd0;
                        for (temp_i = 0; temp_i < 16; temp_i = temp_i + 1) begin
                            if (!removed[temp_i]) begin
                                temp_remaining <= temp_remaining + 4'd1;
                            end
                        end

                        if (temp_remaining == 4'd1) begin
                            state <= SUCCESS;
                        end else begin
                            state <= FAIL;
                        end
                    end else begin
                        for (temp_i = 0; temp_i < 16; temp_i = temp_i + 1) begin
                            if (!removed[temp_i] && degree[temp_i] == 4'd1) begin
                                for (temp_j = 0; temp_j < 16; temp_j = temp_j + 1) begin
                                    if (adj_matrix[temp_i][temp_j] && !removed[temp_j]) begin
                                        degree[temp_j] <= degree[temp_j] - 4'd1;
                                    end
                                end
                                removed[temp_i] <= 1'b1;
                            end
                        end
                        iter <= iter + 4'd1;
                        state <= COMPUTE;
                    end
                end

                FAIL: begin
                    result <= 1'b0;
                    state <= DONE_STATE;
                end

                SUCCESS: begin
                    result <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule