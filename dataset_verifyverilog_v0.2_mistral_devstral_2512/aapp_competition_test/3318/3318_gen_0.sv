module tree_marking (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] D,
    input [14*4-1:0] edges,
    output reg [3:0] result,
    output reg done
);

    // States
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        ENUMERATE,
        VALIDATE,
        UPDATE_MAX,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [14:0] current_mask;
    reg [3:0] max_count;
    reg [3:0] current_count;
    reg [3:0] i, j;
    reg [3:0] node_a, node_b;
    reg [3:0] depth [0:14];
    reg [3:0] parent [0:14];
    reg [3:0] dist;
    reg valid;
    reg [3:0] temp_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            current_mask <= 0;
            max_count <= 0;
            i <= 0;
            j <= 0;
            node_a <= 0;
            node_b <= 0;
            dist <= 0;
            valid <= 1;
            temp_count <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                if (i == N-1) next_state = ENUMERATE;
            end
            ENUMERATE: begin
                if (current_mask == (1 << N) - 1) next_state = DONE;
                else next_state = VALIDATE;
            end
            VALIDATE: begin
                if (valid && (i == N-1)) next_state = UPDATE_MAX;
                else if (!valid) next_state = ENUMERATE;
            end
            UPDATE_MAX: begin
                next_state = ENUMERATE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    result <= 0;
                end
                INIT: begin
                    // Extract parent array from edges
                    for (int k = 0; k < 15; k++) begin
                        parent[k] = edges[(k+1)*4-1:k*4];
                    end
                    // Compute depths
                    depth[0] = 0; // Root depth
                    if (i < N-1) begin
                        i <= i + 1;
                        depth[i] = depth[parent[i]] + 1;
                    end
                end
                ENUMERATE: begin
                    // Generate next mask
                    current_mask <= current_mask + 1;
                    i <= 0;
                    j <= 0;
                    valid <= 1;
                    temp_count <= 0;
                end
                VALIDATE: begin
                    if (valid) begin
                        if (current_mask[i]) begin
                            temp_count <= temp_count + 1;
                            node_a <= i;
                            j <= i + 1;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        i <= 0;
                        j <= 0;
                    end
                    // Check pairs
                    if (current_mask[i] && current_mask[j] && j < N) begin
                        if (j == N-1) begin
                            i <= i + 1;
                            j <= i + 1;
                        end else begin
                            j <= j + 1;
                        end
                        // Compute distance between i and j
                        node_a <= i;
                        node_b <= j;
                        dist <= compute_distance(node_a, node_b, parent, depth);
                        if (dist < D) valid <= 0;
                    end
                end
                UPDATE_MAX: begin
                    if (temp_count > max_count) begin
                        max_count <= temp_count;
                    end
                end
                DONE: begin
                    done <= 1;
                    result <= max_count;
                end
            endcase
        end
    end

    // Distance computation function
    function [3:0] compute_distance;
        input [3:0] a, b;
        input [3:0] parent [0:14];
        input [3:0] depth [0:14];
        reg [3:0] d;
        reg [3:0] lca;
        reg [3:0] temp_a, temp_b;
        begin
            temp_a = a;
            temp_b = b;
            // Find LCA
            while (temp_a != temp_b) begin
                if (depth[temp_a] > depth[temp_b]) begin
                    temp_a = parent[temp_a];
                end else begin
                    temp_b = parent[temp_b];
                end
            end
            lca = temp_a;
            d = depth[a] + depth[b] - 2 * depth[lca];
            compute_distance = d;
        end
    endfunction

endmodule