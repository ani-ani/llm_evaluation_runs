module bfs_validator (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_idx,
    input [2:0] neighbor_idx,
    input adj_write,
    input [2:0] seq_in,
    input seq_write,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_ADJ,
        LOAD_SEQ,
        VERIFY_INIT,
        VERIFY_PROCESS,
        VALID_DONE,
        INVALID_DONE
    } state_t;

    state_t current_state, next_state;

    // Storage registers
    reg [7:0] adj_matrix [0:7];
    reg [2:0] sequence [0:7];
    reg [7:0] visited;
    reg [2:0] parent [0:7];

    // Control signals
    reg [2:0] adj_row_idx;
    reg [2:0] seq_idx;
    reg [2:0] seq_pos;
    reg [2:0] verify_child_idx;
    reg [2:0] neighbor_count;
    reg [2:0] expected_children;
    reg [2:0] child_check_pos;
    reg [7:0] unvisited_children;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            valid <= 0;
            done <= 0;
            adj_row_idx <= 0;
            seq_idx <= 0;
            seq_pos <= 0;
            verify_child_idx <= 0;
            neighbor_count <= 0;
            expected_children <= 0;
            child_check_pos <= 0;
            unvisited_children <= 0;
            visited <= 0;
            for (int i = 0; i < 8; i++) begin
                adj_matrix[i] <= 0;
                sequence[i] <= 0;
                parent[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_ADJ;
            end
            LOAD_ADJ: begin
                if (adj_row_idx == 7) next_state = LOAD_SEQ;
            end
            LOAD_SEQ: begin
                if (seq_idx == 7) next_state = VERIFY_INIT;
            end
            VERIFY_INIT: begin
                if (sequence[0] == 0) next_state = VERIFY_PROCESS;
                else next_state = INVALID_DONE;
            end
            VERIFY_PROCESS: begin
                if (seq_pos == 7) next_state = VALID_DONE;
                else if (sequence[seq_pos] != verify_child_idx && child_check_pos == expected_children) next_state = INVALID_DONE;
            end
            VALID_DONE: begin
                next_state = IDLE;
            end
            INVALID_DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Adjacency matrix loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adj_row_idx <= 0;
        end else if (current_state == LOAD_ADJ && adj_write) begin
            adj_matrix[node_idx][neighbor_idx] <= 1;
            if (neighbor_idx == 7) adj_row_idx <= node_idx + 1;
        end
    end

    // Sequence loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_idx <= 0;
        end else if (current_state == LOAD_SEQ && seq_write) begin
            sequence[seq_idx] <= seq_in;
            seq_idx <= seq_idx + 1;
        end
    end

    // Verification logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_pos <= 0;
            verify_child_idx <= 0;
            neighbor_count <= 0;
            expected_children <= 0;
            child_check_pos <= 0;
            unvisited_children <= 0;
            visited <= 0;
        end else if (current_state == VERIFY_INIT) begin
            visited[sequence[0]] <= 1;
            parent[sequence[0]] <= 0;
            seq_pos <= 1;
            verify_child_idx <= 0;
            neighbor_count <= 0;
            expected_children <= 0;
            child_check_pos <= 0;
            unvisited_children <= 0;
        end else if (current_state == VERIFY_PROCESS) begin
            // Check if current node is valid
            if (seq_pos == 0) begin
                // Already checked in VERIFY_INIT
            end else begin
                // Check if current node is visited
                if (!visited[sequence[seq_pos]]) begin
                    // Check if it's a child of the previous node
                    if (adj_matrix[sequence[seq_pos-1]][sequence[seq_pos]]) begin
                        visited[sequence[seq_pos]] <= 1;
                        parent[sequence[seq_pos]] <= sequence[seq_pos-1];
                    end else begin
                        next_state = INVALID_DONE;
                    end
                end
            end

            // Count unvisited children of current node
            if (seq_pos < 7) begin
                neighbor_count = 0;
                unvisited_children = 0;
                for (int i = 0; i < 8; i++) begin
                    if (adj_matrix[sequence[seq_pos]][i] && !visited[i]) begin
                        neighbor_count = neighbor_count + 1;
                        unvisited_children[i] = 1;
                    end
                end
                expected_children = neighbor_count;
                child_check_pos = 0;
                verify_child_idx = seq_pos + 1;
            end

            // Verify children
            if (expected_children > 0 && child_check_pos < expected_children) begin
                if (unvisited_children[sequence[verify_child_idx]]) begin
                    child_check_pos = child_check_pos + 1;
                    verify_child_idx = verify_child_idx + 1;
                end else begin
                    next_state = INVALID_DONE;
                end
            end else begin
                seq_pos = seq_pos + 1;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 0;
            done <= 0;
        end else begin
            case (current_state)
                VALID_DONE: begin
                    valid <= 1;
                    done <= 1;
                end
                INVALID_DONE: begin
                    valid <= 0;
                    done <= 1;
                end
                default: begin
                    valid <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule