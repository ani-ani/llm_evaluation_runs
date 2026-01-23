module bst_insertion (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    output reg [7:0] cumulative_depth,
    output reg done
);

    // Parameters
    parameter NUM_NODES = 8;
    parameter IDLE = 3'b000;
    parameter LOAD_ROOT = 3'b001;
    parameter SEARCH_INSERT = 3'b010;
    parameter UPDATE_DEPTH = 3'b011;
    parameter DONE = 3'b100;
    parameter IGNORE = 3'b101;

    // Registers for Tree Structure
    reg [7:0] node_val [0:7];
    reg [2:0] left_child [0:7];
    reg [2:0] right_child [0:7];
    
    // Control Registers
    reg [2:0] state, next_state;
    reg [2:0] insertion_count;
    reg [2:0] current_node_index;
    reg [2:0] next_node_index;
    reg [2:0] current_depth;
    reg [7:0] stored_data_in;
    
    integer i;

    // State Transition and FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cumulative_depth <= 8'b0;
            done <= 1'b0;
            insertion_count <= 3'b0;
            // Reset Tree Structure
            for (i = 0; i < 8; i = i + 1) begin
                node_val[i] <= 8'b0;
                left_child[i] <= 3'b111; // 3'b111 maps to 3'h7 which is valid index or could be sentinel. Spec says 0xFF (8'hFF). 3 bits cannot hold 8'hFF. Assuming 3'h7 is "no child" based on N=8.
                right_child[i] <= 3'b111;
            end
        end else begin
            state <= next_state;
            
            if (state == IDLE && start) begin
                stored_data_in <= data_in;
                done <= 1'b0;
            end

            if (state == LOAD_ROOT) begin
                current_node_index <= 3'b000;
                current_depth <= 3'b000;
            end

            if (state == SEARCH_INSERT) begin
                current_node_index <= next_node_index;
                current_depth <= current_depth + 1'b1;
            end

            if (state == UPDATE_DEPTH) begin
                cumulative_depth <= cumulative_depth + current_depth;
                insertion_count <= insertion_count + 1'b1;
            end

            if (state == DONE || state == IGNORE) begin
                done <= 1'b1;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (insertion_count == NUM_NODES) begin
                        next_state = IGNORE;
                    end else begin
                        next_state = LOAD_ROOT;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_ROOT: begin
                if (insertion_count == 3'b000) begin
                    next_state = UPDATE_DEPTH; // Root is the first node, depth 0
                end else begin
                    next_state = SEARCH_INSERT;
                end
            end

            SEARCH_INSERT: begin
                // Compare stored_data_in with node_val[current_node_index]
                if (stored_data_in < node_val[current_node_index]) begin
                    if (left_child[current_node_index] == 3'b111) begin
                        next_state = UPDATE_DEPTH;
                    end else begin
                        next_state = SEARCH_INSERT;
                    end
                end else if (stored_data_in > node_val[current_node_index]) begin
                    if (right_child[current_node_index] == 3'b111) begin
                        next_state = UPDATE_DEPTH;
                    end else begin
                        next_state = SEARCH_INSERT;
                    end
                end else begin
                    // Duplicate or same value found (should not happen per spec, but safe handling)
                    next_state = IGNORE;
                end
            end

            UPDATE_DEPTH: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            IGNORE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Combinational Logic for Next Node and Tree Update
    always @(*) begin
        // Defaults
        next_node_index = current_node_index;
        
        // Logic specific to SEARCH_INSERT state to determine next node
        if (state == SEARCH_INSERT) begin
            if (stored_data_in < node_val[current_node_index]) begin
                next_node_index = left_child[current_node_index];
            end else if (stored_data_in > node_val[current_node_index]) begin
                next_node_index = right_child[current_node_index];
            end else begin
                next_node_index = current_node_index; // Should not reach here if state logic is correct
            end
        end
    end

    // Tree Update Logic (Latched in UPDATE_DEPTH state)
    // We need to perform the write to the tree structure registers.
    // Since Verilog always blocks are sequential, we detect the transition or use the logic inside the main block.
    // However, to keep logic clean and avoid races, let's handle the writes based on the current state and the previous decision.
    
    // To properly implement the tree insertion without combinational loop on "node_val" etc, 
    // we need to know WHERE we are inserting when we are in UPDATE_DEPTH.
    // The 'current_node_index' at the start of UPDATE_DEPTH is the PARENT of the new node.
    // Wait, checking the state flow: 
    // SEARCH_INSERT checks the current node. If it has no child, it goes to UPDATE_DEPTH.
    // In SEARCH_INSERT, we advance 'current_node_index' to the child pointer (which is null/not valid, but the index register holds the 'target' index? No, the pointer is 0xFF/3'h7).
    
    // Let's refine the flow:
    // 1. LOAD_ROOT sets current_node_index to 0.
    // 2. SEARCH_INCREMENT increments depth.
    //    In SEARCH_INSERT, we check if current_node_val > stored_data.
    //    We look at left_child[current_node_index]. If it is 3'h7 (empty), we stay at UPDATE_DEPTH.
    //    But we need to know WHICH child slot to fill (left or right).
    
    // Let's add a register to store the direction (0=left, 1=right, 2=root) for the insertion.
    reg [1:0] insert_direction; // 0: Left, 1: Right, 2: Root (special)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            insert_direction <= 2'b0;
        end else begin
            if (state == SEARCH_INSERT) begin
                if (stored_data_in < node_val[current_node_index]) begin
                    if (left_child[current_node_index] == 3'b111) insert_direction <= 2'b00;
                end else if (stored_data_in > node_val[current_node_index]) begin
                    if (right_child[current_node_index] == 3'b111) insert_direction <= 2'b01;
                end
            end else if (state == LOAD_ROOT) begin
                insert_direction <= 2'b10; // Special flag for root
            end
        end
    end

    // Actual Tree Register Updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled in FSM block
        end else begin
            if (state == UPDATE_DEPTH) begin
                if (insert_direction == 2'b10) begin
                    // Inserting Root (only happens once)
                    // Node index is always 0 for the first node in this design requirement (allocate next free)
                    // But to be robust, let's say we allocate indices sequentially: 0, 1, 2...
                    // Node 0 is reserved for root? Or just first available.
                    // Spec says "Use node indices 0-7". "first inserted value becomes root".
                    // Let's use index 0 as root. 
                    node_val[0] <= stored_data_in;
                end else if (insert_direction == 2'b00) begin
                    // Insert Left
                    // We need to know the NEW node index. 
                    // Since we fill sequentially, new index = insertion_count.
                    node_val[insertion_count] <= stored_data_in;
                    left_child[current_node_index] <= insertion_count;
                end else if (insert_direction == 2'b01) begin
                    // Insert Right
                    node_val[insertion_count] <= stored_data_in;
                    right_child[current_node_index] <= insertion_count;
                end
            end
        end
    end

endmodule
