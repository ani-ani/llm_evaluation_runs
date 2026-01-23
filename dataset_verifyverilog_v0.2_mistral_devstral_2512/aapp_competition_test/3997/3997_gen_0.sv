module tree_control(
    input clk,
    input rst_n,
    input start,
    // Tree structure: fixed 8 nodes, indexed 0-7 (root is 0)
    // Children encoded as bitmasks: child_mask[i] has bit j set if j is child of i
    input [7:0] child_mask_0,
    input [7:0] child_mask_1,
    input [7:0] child_mask_2,
    input [7:0] child_mask_3,
    input [7:0] child_mask_4,
    input [7:0] child_mask_5,
    input [7:0] child_mask_6,
    input [7:0] child_mask_7,
    // Edge weights (16-bit, weights up to 65535)
    input [15:0] edge_weight_01, input [15:0] edge_weight_02, input [15:0] edge_weight_03,
    input [15:0] edge_weight_04, input [15:0] edge_weight_05, input [15:0] edge_weight_06,
    input [15:0] edge_weight_07,
    input [15:0] edge_weight_12, input [15:0] edge_weight_13, input [15:0] edge_weight_14,
    input [15:0] edge_weight_15, input [15:0] edge_weight_16, input [15:0] edge_weight_17,
    input [15:0] edge_weight_23, input [15:0] edge_weight_24, input [15:0] edge_weight_25,
    input [15:0] edge_weight_26, input [15:0] edge_weight_27,
    input [15:0] edge_weight_34, input [15:0] edge_weight_35, input [15:0] edge_weight_36,
    input [15:0] edge_weight_37,
    input [15:0] edge_weight_45, input [15:0] edge_weight_46, input [15:0] edge_weight_47,
    input [15:0] edge_weight_56, input [15:0] edge_weight_57,
    input [15:0] edge_weight_67,
    // Control values a_i (16-bit)
    input [15:0] a_0, input [15:0] a_1, input [15:0] a_2, input [15:0] a_3,
    input [15:0] a_4, input [15:0] a_5, input [15:0] a_6, input [15:0] a_7,
    output reg [2:0] result_index,  // Which node's result is being output (0-7)
    output reg [3:0] result_value,  // Number of vertices controlled by node result_index
    output reg done                 // High when all 8 results are computed
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        VISIT,
        CHECK,
        UPDATE,
        OUTPUT,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [2:0] current_node;          // Current node being processed (0-7)
    reg [2:0] ancestor_node;         // Current ancestor being checked (0-7)
    reg [2:0] descendant_node;       // Current descendant being checked (0-7)
    reg [15:0] distance_register [0:7]; // Stores dist(root, node) for each node
    reg [3:0] control_count [0:7];   // Stores result for each node
    reg [2:0] stack_ptr;             // Stack pointer for DFS traversal
    reg [2:0] stack [0:7];           // Traversal stack (max depth 8)
    reg [15:0] cumulative_distance;  // Current cumulative distance from ancestor
    reg [2:0] output_counter;        // Counter for output phase

    // Edge weight lookup table
    reg [15:0] edge_weights [0:7][0:7];

    // Initialize edge weights
    always @* begin
        edge_weights[0][1] = edge_weight_01; edge_weights[0][2] = edge_weight_02; edge_weights[0][3] = edge_weight_03;
        edge_weights[0][4] = edge_weight_04; edge_weights[0][5] = edge_weight_05; edge_weights[0][6] = edge_weight_06;
        edge_weights[0][7] = edge_weight_07;
        edge_weights[1][2] = edge_weight_12; edge_weights[1][3] = edge_weight_13; edge_weights[1][4] = edge_weight_14;
        edge_weights[1][5] = edge_weight_15; edge_weights[1][6] = edge_weight_16; edge_weights[1][7] = edge_weight_17;
        edge_weights[2][3] = edge_weight_23; edge_weights[2][4] = edge_weight_24; edge_weights[2][5] = edge_weight_25;
        edge_weights[2][6] = edge_weight_26; edge_weights[2][7] = edge_weight_27;
        edge_weights[3][4] = edge_weight_34; edge_weights[3][5] = edge_weight_35; edge_weights[3][6] = edge_weight_36;
        edge_weights[3][7] = edge_weight_37;
        edge_weights[4][5] = edge_weight_45; edge_weights[4][6] = edge_weight_46; edge_weights[4][7] = edge_weight_47;
        edge_weights[5][6] = edge_weight_56; edge_weights[5][7] = edge_weight_57;
        edge_weights[6][7] = edge_weight_67;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 0;
            ancestor_node <= 0;
            descendant_node <= 0;
            stack_ptr <= 0;
            output_counter <= 0;
            cumulative_distance <= 0;
            for (int i = 0; i < 8; i++) begin
                distance_register[i] <= 0;
                control_count[i] <= 0;
            end
            result_index <= 0;
            result_value <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            SETUP: begin
                next_state = VISIT;
            end
            VISIT: begin
                next_state = CHECK;
            end
            CHECK: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                if (output_counter == 7) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                SETUP: begin
                    // Initialize for DFS traversal
                    stack_ptr <= 1;
                    stack[0] <= 0;  // Start with root node
                    current_node <= 0;
                    distance_register[0] <= 0;
                end
                VISIT: begin
                    // Process current node and push children onto stack
                    if (stack_ptr > 0) begin
                        current_node <= stack[stack_ptr - 1];
                        stack_ptr <= stack_ptr - 1;

                        // Push children onto stack (in reverse order for DFS)
                        for (int i = 7; i >= 0; i--) begin
                            if (i != current_node && (child_mask(current_node) & (1 << i))) begin
                                stack[stack_ptr] <= i;
                                stack_ptr <= stack_ptr + 1;
                                distance_register[i] <= distance_register[current_node] + edge_weights[current_node][i];
                            end
                        end
                    end
                end
                CHECK: begin
                    // Check control condition for all ancestor-descendant pairs
                    for (int v = 0; v < 8; v++) begin
                        for (int u = 0; u < 8; u++) begin
                            if (v != u && (child_mask(v) & (1 << u))) begin
                                cumulative_distance <= distance_register[u] - distance_register[v];
                                if (cumulative_distance <= a[u]) begin
                                    control_count[v] <= control_count[v] + 1;
                                end
                            end
                        end
                    end
                end
                UPDATE: begin
                    // Prepare for output phase
                    output_counter <= 0;
                end
                OUTPUT: begin
                    // Output results sequentially
                    result_index <= output_counter;
                    result_value <= control_count[output_counter];
                    output_counter <= output_counter + 1;
                    if (output_counter == 7) done <= 1;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Helper function to get child mask for current node
    function [7:0] child_mask(input [2:0] node);
        case (node)
            0: child_mask = child_mask_0;
            1: child_mask = child_mask_1;
            2: child_mask = child_mask_2;
            3: child_mask = child_mask_3;
            4: child_mask = child_mask_4;
            5: child_mask = child_mask_5;
            6: child_mask = child_mask_6;
            7: child_mask = child_mask_7;
            default: child_mask = 8'b0;
        endcase
    endfunction

endmodule