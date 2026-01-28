module magical_colors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,
    input wire [3:0] node_idx,
    input wire [3:0] new_color,
    output reg [7:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [3:0] MAX_COLORS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UPDATE = 3'd1;
    localparam [2:0] QUERY = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [3:0] current_node;
    reg [3:0] current_color;
    reg [3:0] freq [0:15];
    reg [3:0] colors [0:15];
    reg [3:0] parent [0:15];
    reg [3:0] tin [0:15];
    reg [3:0] tout [0:15];
    reg [3:0] time_counter;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] temp_result;

    // Initialize parent array (example: binary tree for simplicity)
    integer i;
    initial begin
        parent[0] = 4'd0; // Root has no parent
        parent[1] = 4'd0; // Node 2's parent is 1
        parent[2] = 4'd1; // Node 3's parent is 1
        parent[3] = 4'd1; // Node 4's parent is 1
        parent[4] = 4'd2; // Node 5's parent is 2
        parent[5] = 4'd2; // Node 6's parent is 2
        parent[6] = 4'd3; // Node 7's parent is 3
        parent[7] = 4'd3; // Node 8's parent is 3
        parent[8] = 4'd4; // Node 9's parent is 4
        parent[9] = 4'd4; // Node 10's parent is 4
        parent[10] = 4'd5; // Node 11's parent is 5
        parent[11] = 4'd5; // Node 12's parent is 5
        parent[12] = 4'd6; // Node 13's parent is 6
        parent[13] = 4'd6; // Node 14's parent is 6
        parent[14] = 4'd7; // Node 15's parent is 7
        parent[15] = 4'd7; // Node 16's parent is 7
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_node <= 4'd0;
            current_color <= 4'd0;
            temp_result <= 8'd0;
            done <= 1'b0;
            result <= 8'd0;
            time_counter <= 4'd0;
            stack_ptr <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                freq[i] <= 4'd0;
                colors[i] <= 4'd0;
                tin[i] <= 4'd0;
                tout[i] <= 4'd0;
                stack[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (op_type) begin
                            state <= UPDATE;
                        end else begin
                            state <= QUERY;
                        end
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count == 8'd1) begin
                        colors[node_idx - 1] <= new_color;
                        state <= FINISH;
                    end
                end

                QUERY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count == 8'd1) begin
                        // Reset frequency array
                        for (i = 0; i < 16; i = i + 1) begin
                            freq[i] <= 4'd0;
                        end
                        // Perform DFS to compute tin and tout
                        time_counter <= 4'd0;
                        stack_ptr <= 4'd0;
                        stack[0] <= 4'd0; // Start with root (node 1, index 0)
                        current_node <= 4'd0;
                    end else if (cycle_count > 8'd1 && cycle_count < 8'd32) begin
                        // DFS traversal
                        if (stack_ptr > 4'd0) begin
                            current_node <= stack[stack_ptr];
                            stack_ptr <= stack_ptr - 4'd1;
                            // Check if current_node is in subtree of node_idx
                            if (is_in_subtree(current_node, node_idx - 1)) begin
                                current_color <= colors[current_node];
                                freq[current_color] <= freq[current_color] ^ 4'd1;
                            end
                            // Push children to stack
                            for (i = 0; i < 16; i = i + 1) begin
                                if (parent[i] == current_node) begin
                                    stack_ptr <= stack_ptr + 4'd1;
                                    stack[stack_ptr] <= i;
                                end
                            end
                        end
                    end else if (cycle_count == 8'd32) begin
                        // Count magical colors
                        temp_result <= 8'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (freq[i] == 4'd1) begin
                                temp_result <= temp_result + 8'd1;
                            end
                        end
                        result <= temp_result;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Helper function to check if node is in subtree
    function is_in_subtree;
        input [3:0] node;
        input [3:0] root;
        reg [3:0] current;
        begin
            current = node;
            while (current != root && current != 4'd0) begin
                current = parent[current];
            end
            is_in_subtree = (current == root);
        end
    endfunction

endmodule