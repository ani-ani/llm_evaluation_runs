module LongestJumpingPath(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [7:0] labels [0:15],
    input wire [3:0] parents [1:15],
    output reg [7:0] result_len,
    output reg [23:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_CHILD_LIST = 3'd1;
    localparam [2:0] COMPUTE_POSTORDER = 3'd2;
    localparam [2:0] PROCESS_NODE = 3'd3;
    localparam [2:0] UPDATE_CHILD_RESULTS = 3'd4;
    localparam [2:0] FIND_MAX_AND_COUNT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Constants
    localparam [7:0] MAX_LABEL = 8'd255;
    localparam [23:0] MODULO = 24'd11092019;
    localparam [3:0] MAX_NODES = 4'd16;

    // State machine
    reg [2:0] state, next_state;

    // Counters and indices
    reg [3:0] node_idx;
    reg [3:0] label_idx;
    reg [3:0] child_idx;
    reg [3:0] stack_ptr;
    reg [3:0] post_order_ptr;
    reg [3:0] current_node;
    reg [3:0] temp_node;

    // Stack for DFS
    reg [3:0] stack [0:15];

    // Post-order traversal array
    reg [3:0] post_order [0:15];

    // Child list
    reg [3:0] child_list [0:15];
    reg [3:0] child_count [0:15];

    // DP table: 16 nodes x 256 labels
    reg [7:0] dp_len [0:15][0:255];
    reg [23:0] dp_count [0:15][0:255];

    // Temporary storage for processing
    reg [7:0] current_label;
    reg [7:0] max_length;
    reg [23:0] total_count;
    reg [7:0] child_length;
    reg [23:0] child_count_val;
    reg [7:0] new_length;
    reg [23:0] new_count;

    // Cycle counter for safety
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2000;

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            node_idx <= 4'd0;
            label_idx <= 4'd0;
            child_idx <= 4'd0;
            stack_ptr <= 4'd0;
            post_order_ptr <= 4'd0;
            current_node <= 4'd0;
            temp_node <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 4'd0;
                post_order[i] <= 4'd0;
                child_list[i] <= 4'd0;
                child_count[i] <= 4'd0;
                for (j = 0; j < 256; j = j + 1) begin
                    dp_len[i][j] <= 8'd0;
                    dp_count[i][j] <= 24'd0;
                end
            end
            current_label <= 8'd0;
            max_length <= 8'd0;
            total_count <= 24'd0;
            child_length <= 8'd0;
            child_count_val <= 24'd0;
            new_length <= 8'd0;
            new_count <= 24'd0;
            result_len <= 8'd0;
            result_count <= 24'd0;
            done <= 1'b0;
            cycle_count <= 11'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        next_state <= BUILD_CHILD_LIST;
                        node_idx <= 4'd0;
                    end
                end

                BUILD_CHILD_LIST: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (node_idx < N) begin
                        // Initialize child count
                        child_count[node_idx] <= 4'd0;
                        // Find children
                        for (i = 1; i < 16; i = i + 1) begin
                            if (parents[i] == node_idx) begin
                                child_list[i] <= node_idx;
                                child_count[node_idx] <= child_count[node_idx] + 4'd1;
                            end
                        end
                        node_idx <= node_idx + 4'd1;
                    end else begin
                        next_state <= COMPUTE_POSTORDER;
                        stack_ptr <= 4'd0;
                        stack[0] <= 4'd0; // Start with root
                        post_order_ptr <= 4'd0;
                    end
                end

                COMPUTE_POSTORDER: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (stack_ptr > 4'd0) begin
                        temp_node <= stack[stack_ptr];
                        stack_ptr <= stack_ptr - 4'd1;
                        // Check if all children processed
                        reg all_children_processed;
                        integer k;
                        all_children_processed = 1'b1;
                        for (k = 0; k < child_count[temp_node]; k = k + 1) begin
                            // Check if child is in post_order
                            reg found;
                            integer m;
                            found = 1'b0;
                            for (m = 0; m < post_order_ptr; m = m + 1) begin
                                if (post_order[m] == child_list[k]) begin
                                    found = 1'b1;
                                end
                            end
                            if (!found) begin
                                all_children_processed = 1'b0;
                            end
                        end
                        if (all_children_processed) begin
                            post_order[post_order_ptr] <= temp_node;
                            post_order_ptr <= post_order_ptr + 4'd1;
                        end else begin
                            // Push back and push unprocessed children
                            stack_ptr <= stack_ptr + 4'd1;
                            stack[stack_ptr] <= temp_node;
                            for (k = 0; k < child_count[temp_node]; k = k + 1) begin
                                reg found;
                                integer m;
                                found = 1'b0;
                                for (m = 0; m < post_order_ptr; m = m + 1) begin
                                    if (post_order[m] == child_list[k]) begin
                                        found = 1'b1;
                                    end
                                end
                                if (!found) begin
                                    stack_ptr <= stack_ptr + 4'd1;
                                    stack[stack_ptr] <= child_list[k];
                                end
                            end
                        end
                    end else if (stack_ptr == 4'd0) begin
                        if (post_order_ptr == N) begin
                            next_state <= PROCESS_NODE;
                            node_idx <= 4'd0;
                        end
                    end
                end

                PROCESS_NODE: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (node_idx < N) begin
                        current_node <= post_order[node_idx];
                        current_label <= labels[current_node];
                        // Initialize DP for current node
                        for (i = 0; i < 256; i = i + 1) begin
                            dp_len[current_node][i] <= 8'd0;
                            dp_count[current_node][i] <= 24'd0;
                        end
                        dp_len[current_node][current_label] <= 8'd1;
                        dp_count[current_node][current_label] <= 24'd1;
                        child_idx <= 4'd0;
                        next_state <= UPDATE_CHILD_RESULTS;
                    end else begin
                        next_state <= FIND_MAX_AND_COUNT;
                        max_length <= 8'd0;
                        total_count <= 24'd0;
                        node_idx <= 4'd0;
                    end
                end

                UPDATE_CHILD_RESULTS: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (child_idx < child_count[current_node]) begin
                        temp_node <= child_list[child_idx];
                        label_idx <= 4'd0;
                        // Process each label
                        for (i = 0; i < 256; i = i + 1) begin
                            if (dp_len[temp_node][i] > 8'd0) begin
                                if (i >= current_label) begin
                                    child_length <= dp_len[temp_node][i];
                                    child_count_val <= dp_count[temp_node][i];
                                    new_length <= child_length + 8'd1;
                                    new_count <= child_count_val;
                                    // Update DP
                                    if (new_length > dp_len[current_node][i]) begin
                                        dp_len[current_node][i] <= new_length;
                                        dp_count[current_node][i] <= new_count;
                                    end else if (new_length == dp_len[current_node][i]) begin
                                        dp_count[current_node][i] <= (dp_count[current_node][i] + new_count) % MODULO;
                                    end
                                end
                            end
                        end
                        child_idx <= child_idx + 4'd1;
                    end else begin
                        child_idx <= 4'd0;
                        node_idx <= node_idx + 4'd1;
                        next_state <= PROCESS_NODE;
                    end
                end

                FIND_MAX_AND_COUNT: begin
                    cycle_count <= cycle_count + 11'd1;
                    if (node_idx < N) begin
                        for (i = 0; i < 256; i = i + 1) begin
                            if (dp_len[node_idx][i] > max_length) begin
                                max_length <= dp_len[node_idx][i];
                                total_count <= dp_count[node_idx][i];
                            end else if (dp_len[node_idx][i] == max_length) begin
                                total_count <= (total_count + dp_count[node_idx][i]) % MODULO;
                            end
                        end
                        node_idx <= node_idx + 4'd1;
                    end else begin
                        result_len <= max_length;
                        result_count <= total_count;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule