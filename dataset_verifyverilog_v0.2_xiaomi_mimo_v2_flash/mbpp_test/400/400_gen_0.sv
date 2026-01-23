module unique_tuples (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple_data [0:3][0:1],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        LOAD = 3'b001,
        COMPARE = 3'b010,
        COUNT = 3'b011,
        DONE = 3'b100
    } state_t;
    
    state_t current_state, next_state;

    // Processing registers
    reg [7:0] current_tuple [0:1]; // Processing tuple
    reg [7:0] stored_tuples [0:3][0:1]; // Stored unique tuples
    reg [3:0] stored_valid; // Bitmask for valid stored tuples
    reg [2:0] tuple_idx; // Index of tuple being processed (0-3)

    // Combinational comparison results
    wire [3:0] match_results;
    wire is_unique;

    // Combinational comparison logic
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_comparisons
            assign match_results[i] = stored_valid[i] &
                                      (current_tuple[0] == stored_tuples[i][0]) &
                                      (current_tuple[1] == stored_tuples[i][1]);
        end
    endgenerate

    assign is_unique = (match_results == 4'b0000);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all sequential logic
            result <= 4'b0;
            done <= 1'b0;
            stored_valid <= 4'b0000;
            tuple_idx <= 3'b0;
            // Initialize stored tuples to X (don't care) but explicit reset good for synthesis
            stored_tuples[0][0] <= 8'b0; stored_tuples[0][1] <= 8'b0;
            stored_tuples[1][0] <= 8'b0; stored_tuples[1][1] <= 8'b0;
            stored_tuples[2][0] <= 8'b0; stored_tuples[2][1] <= 8'b0;
            stored_tuples[3][0] <= 8'b0; stored_tuples[3][1] <= 8'b0;
            current_tuple[0] <= 8'b0;
            current_tuple[1] <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for processing
                        stored_valid <= 4'b0000;
                        result <= 4'b0;
                        tuple_idx <= 3'b0;
                        // Load first tuple immediately
                        current_tuple[0] <= tuple_data[0][0];
                        current_tuple[1] <= tuple_data[0][1];
                    end
                end

                LOAD: begin
                    // Load next tuple based on index
                    // If tuple_idx is 0, we already loaded it in IDLE/transition
                    // But to keep it clean, we load here based on index before COMPARE
                    if (tuple_idx < 4) begin
                        current_tuple[0] <= tuple_data[tuple_idx][0];
                        current_tuple[1] <= tuple_data[tuple_idx][1];
                    end
                end

                COMPARE: begin
                    // Wait for combinational comparison result
                    // Do nothing, transition handles update
                end

                COUNT: begin
                    // Update storage and count
                    if (is_unique) begin
                        // Add current tuple to next free slot (or specific index logic)
                        // The spec says "Use 4 registers to store valid tuples".
                        // We fill them sequentially.
                        // Since result is the count, we can use result as the index for the new entry.
                        stored_tuples[result][0] <= current_tuple[0];
                        stored_tuples[result][1] <= current_tuple[1];
                        stored_valid[result] <= 1'b1;
                        result <= result + 1;
                    end
                    // Increment index
                    tuple_idx <= tuple_idx + 1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state decoder (Moore style logic)
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end

            LOAD: begin
                next_state = COMPARE;
            end

            COMPARE: begin
                next_state = COUNT;
            end

            COUNT: begin
                // Check if we processed all 4 tuples
                // tuple_idx was incremented in COUNT state logic above,
                // but for comparison we need to check if we just incremented to 4 (meaning 0..3 done)
                // Or we check if next tuple_idx is 4.
                // Wait, tuple_idx increments here. So after processing idx 3, it becomes 4.
                if (tuple_idx == 3'd3) begin // Check PREVIOUS value or current state logic? 
                    // Wait, logic above: tuple_idx increments in COUNT.
                    // If current tuple_idx (before increment) was 3 (the 4th one), we are done.
                    // Actually, simpler: if (tuple_idx == 3'd3) means we just processed the 4th one.
                    // Let's track the next state condition carefully.
                    // The state is entered, we process the tuple at 'tuple_idx'.
                    // If 'tuple_idx' is 3, it's the last one.
                    next_state = DONE;
                end else if (tuple_idx < 3'd3) begin
                    // We haven't processed index 3 yet.
                    next_state = LOAD;
                end else begin
                     // Fallback (should not happen if logic is correct)
                     next_state = DONE;
                end
                
                // Logic correction:
                // Cycle 0 (IDLE->LOAD): tuple_idx=0. Loads T0.
                // Cycle 1 (LOAD->COMPARE).
                // Cycle 2 (COMPARE->COUNT).
                // Cycle 3 (COUNT): Process T0. tuple_idx becomes 1. If tuple_idx == 3 is false (0!=3). Next state LOAD.
                // Cycle 4 (LOAD): Loads T1. tuple_idx=1.
                // ...
                // Cycle N (COUNT): Process T3 (idx=3). tuple_idx becomes 4. If tuple_idx == 3 is FALSE (4!=3).
                // We need to check the value BEFORE increment.
                // So: if (tuple_idx == 3'd3) NEXT state DONE. Else LOAD.
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Fix for COUNT state next state logic:
    // We can use the 'next_state' logic derived from current state and 'tuple_idx'.
    // However, the 'always @(*)' block needs to read the 'current' tuple_idx.
    // Since 'tuple_idx' updates on clock edge, inside the combinational block it reflects value from previous cycle.
    // Wait, inside COUNT state, we are checking how to transition out.
    // The 'always @(*)' block runs whenever inputs change.
    // At the start of COUNT cycle, tuple_idx still holds value from LOAD cycle (which is the index we are now processing).
    // So let's use that.
    
    // Re-writing the COUNT part of next_state logic to be explicit:
    // If we are in COUNT, we are processing tuple 'tuple_idx'.
    // If 'tuple_idx' is 3 (the 4th item), we are done after this.
    // Otherwise, go to LOAD.
    
    // Override the COUNT transition logic in the combinational block:
    always @(*) begin
        if (current_state == COUNT) begin
            if (tuple_idx == 3'd3)
                next_state = DONE;
            else
                next_state = LOAD;
        end else if (current_state == IDLE) begin
            if (start) next_state = LOAD; else next_state = IDLE;
        end else if (current_state == LOAD) begin
            next_state = COMPARE;
        end else if (current_state == COMPARE) begin
            next_state = COUNT;
        end else if (current_state == DONE) begin
            next_state = DONE;
        end else begin
            next_state = IDLE;
        end
    end

endmodule