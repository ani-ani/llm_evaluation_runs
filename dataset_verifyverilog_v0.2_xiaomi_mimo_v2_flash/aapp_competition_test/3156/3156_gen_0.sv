module shopping_path_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_stores,
    input [2:0] num_items,
    input [2:0] purchase_order [0:7],
    input [7:0] inventory_matrix [0:7],
    output reg [1:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CHECK_PATH = 3'b001;
    localparam EVALUATE = 3'b010;
    localparam BACKTRACK = 3'b011;
    localparam DONE_STATE = 3'b100;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] depth_cnt; // Current position in purchase_order (0 to num_items-1)
    reg [2:0] path_stack [0:7]; // Stores the chosen store for each depth
    reg [2:0] store_idx; // Candidate store index for current depth (0 to num_stores-1)
    reg [1:0] valid_count; // 0, 1, 2 (capped at 2)
    reg [2:0] item_idx; // Item index from purchase_order
    reg store_has_item;

    // Helper to check if current store has current item
    // inventory_matrix[store_idx] is an 8-bit vector. item_idx selects the bit.
    wire current_inventory_check;
    assign current_inventory_check = inventory_matrix[store_idx][item_idx];

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Reset all logic registers
            depth_cnt <= 3'b0;
            valid_count <= 2'b0;
            store_idx <= 3'b0;
            item_idx <= 3'b0;
            // Clear stack (optional but good practice)
            integer i;
            for (i = 0; i < 8; i = i + 1) path_stack[i] <= 3'b0;
            result <= 2'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        depth_cnt <= 3'b0;
                        valid_count <= 2'b0;
                        store_idx <= 3'b0;
                        item_idx <= purchase_order[0]; // Pre-fetch first item
                        done <= 1'b0;
                    end
                end

                CHECK_PATH: begin
                    // Try current store_idx
                    // Optimization: We don't strictly need to save item_idx to register 
                    // because purchase_order[depth_cnt] is combinational, but keeping it sync avoids timing issues.
                    item_idx <= purchase_order[depth_cnt]; 
                    store_has_item <= current_inventory_check;
                end

                EVALUATE: begin
                    // Decide next state based on check result
                    // Logic handled in combinational block below, 
                    // but we might update counters here or rely on next_state decoding.
                    // Let's update counters here to keep logic clean.
                    
                    if (store_has_item) begin
                        // Valid step found
                        path_stack[depth_cnt] <= store_idx;
                        
                        if (depth_cnt == num_items - 3'b1) begin
                            // Reached end of purchase list (leaf node)
                            if (valid_count < 2) valid_count <= valid_count + 1;
                            // Force backtrack next cycle
                            // We set a flag or just rely on the fact we are at max depth
                            // To handle backtrack state transition correctly, we might need a 'leaf' flag
                            // Or simply set state to BACKTRACK and decrement depth immediately
                        end else begin
                            // Go deeper
                            depth_cnt <= depth_cnt + 1;
                            store_idx <= 3'b0; // Reset store search for next level
                            item_idx <= purchase_order[depth_cnt + 1]; // Pre-fetch next item
                        end
                    end else begin
                        // Current store doesn't have item, try next store
                        store_idx <= store_idx + 1;
                    end
                end

                BACKTRACK: begin
                    // Backtrack logic: move up one level and try next store
                    depth_cnt <= depth_cnt - 1;
                    // Restore item index for the level we returned to
                    item_idx <= purchase_order[depth_cnt - 1];
                    // Load store index for the level we returned to
                    store_idx <= path_stack[depth_cnt - 1] + 1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (valid_count == 0) result <= 2'b00; // Impossible
                    else if (valid_count == 1) result <= 2'b01; // Unique
                    else result <= 2'b10; // Ambiguous
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_PATH;
                else next_state = IDLE;
            end

            CHECK_PATH: begin
                // Just waited one cycle for memory read/logic
                next_state = EVALUATE;
            end

            EVALUATE: begin
                // Logic:
                // 1. If valid (store_has_item):
                //    a. If at max depth (leaf): We found a path. Go to BACKTRACK to try other paths.
                //    b. Else: Go deeper -> CHECK_PATH.
                // 2. If invalid:
                //    a. If stores exhausted (store_idx == num_stores): Backtrack.
                //    b. Else: Try next store -> CHECK_PATH.
                
                if (store_has_item) begin
                    if (depth_cnt == num_items - 3'b1) begin
                        // Found a complete valid path
                        // Check termination condition: count >= 2?
                        if (valid_count >= 1 && (valid_count + 1) >= 2) begin
                            next_state = DONE_STATE; // Early termination
                        end else begin
                            next_state = BACKTRACK; // Look for more paths
                        end
                    end else begin
                        next_state = CHECK_PATH; // Go to next depth
                    end
                end else begin
                    // Try next store at this depth
                    if (store_idx + 1 == num_stores) begin
                        // No more stores to try at this level
                        if (depth_cnt == 0) begin
                            // Backtracked to root and exhausted all stores
                            next_state = DONE_STATE;
                        end else begin
                            next_state = BACKTRACK;
                        end
                    end else begin
                        // Try next store
                        next_state = CHECK_PATH;
                    end
                end
            end

            BACKTRACK: begin
                // One cycle to update registers (depth, store_idx)
                next_state = CHECK_PATH;
            end

            DONE_STATE: begin
                next_state = DONE_STATE; // Stay here until reset
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
