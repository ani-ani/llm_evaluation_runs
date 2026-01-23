module translator_matcher(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_translators,
    input [3:0] num_languages,
    input [1:0] translator_lang1 [0:15],
    input [1:0] translator_lang2 [0:15],
    output reg [3:0] pair1 [0:7],
    output reg [3:0] pair2 [0:7],
    output reg [3:0] num_pairs,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam CHECK_MATCHING = 3'b010;
    localparam FOUND_MATCHING = 3'b100;
    localparam IMPOSSIBLE = 3'b011;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Backtracking stack registers
    // Stack depth max 8 (16/2)
    reg [3:0] stack_t0 [0:7]; // Translator 0 of pair
    reg [3:0] stack_t1 [0:7]; // Translator 1 of pair
    reg [15:0] stack_mask [0:7]; // Mask before pairing
    reg [2:0] sp; // Stack pointer (0 to 8, 8 means full)
    reg [3:0] current_idx; // Current translator index being processed
    reg [3:0] pair_idx;     // Current pairing partner index
    reg [15:0] paired_mask;
    
    // Helper logic for compatibility
    wire compatible;
    assign compatible = (translator_lang1[current_idx] == translator_lang1[pair_idx]) ||
                       (translator_lang1[current_idx] == translator_lang2[pair_idx]) ||
                       (translator_lang2[current_idx] == translator_lang1[pair_idx]) ||
                       (translator_lang2[current_idx] == translator_lang2[pair_idx]);

    // Helper logic to find next free index
    reg [3:0] next_free_idx;
    integer i_next;
    always @(*) begin
        next_free_idx = 4'b1111; // Default invalid
        for (i_next = 0; i_next < 16; i_next = i_next + 1) begin
            if (i_next < num_translators) begin
                if (!paired_mask[i_next]) begin
                    next_free_idx = i_next[3:0];
                    break;
                end
            end
        end
    end

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            num_pairs <= 4'b0;
            paired_mask <= 16'b0;
            sp <= 3'b0;
            current_idx <= 4'b0;
            pair_idx <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                    paired_mask <= 16'b0;
                    sp <= 3'b0;
                    num_pairs <= 4'b0;
                    if (start) begin
                        if (num_translators[0] == 1'b1 || num_translators == 4'b0) begin
                            // Odd number or zero
                            next_state <= IMPOSSIBLE;
                        end else begin
                            // Start search
                            current_idx <= 4'b0;
                            pair_idx <= 4'b0;
                            next_state <= CHECK_MATCHING;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_MATCHING: begin
                    // Logic to traverse tree
                    // 1. Check if we found a valid complete match
                    if (sp == num_translators >> 1) begin
                        // All pairs found
                        next_state <= FOUND_MATCHING;
                    end else begin
                        // 2. Ensure current_idx is the first free index
                        // If paired_mask[current_idx] is set, find next free
                        if (current_idx >= num_translators || paired_mask[current_idx]) begin
                             // Find next free
                             if (next_free_idx >= num_translators) begin
                                // Should not happen if sp logic is correct, but implies done
                                next_state <= IMPOSSIBLE;
                             end else begin
                                current_idx <= next_free_idx;
                                pair_idx <= next_free_idx + 1;
                             end
                        end else begin
                            // 3. Try to pair current_idx with pair_idx
                            if (pair_idx >= num_translators) begin
                                // Backtrack
                                if (sp == 3'b0) begin
                                    // No more options
                                    next_state <= IMPOSSIBLE;
                                end else begin
                                    // Pop stack
                                    sp <= sp - 1;
                                    paired_mask <= stack_mask[sp - 1];
                                    current_idx <= stack_t0[sp - 1];
                                    pair_idx <= stack_t1[sp - 1] + 1;
                                    num_pairs <= num_pairs - 1;
                                end
                            end else if (paired_mask[pair_idx]) begin
                                // Try next
                                pair_idx <= pair_idx + 1;
                            end else if (compatible) begin
                                // Compatible found, Push and advance
                                stack_t0[sp] <= current_idx;
                                stack_t1[sp] <= pair_idx;
                                stack_mask[sp] <= paired_mask;
                                sp <= sp + 1;
                                
                                paired_mask[current_idx] <= 1'b1;
                                paired_mask[pair_idx] <= 1'b1;
                                
                                pair1[num_pairs] <= current_idx;
                                pair2[num_pairs] <= pair_idx;
                                num_pairs <= num_pairs + 1;
                                
                                // Find next free for next iteration (or let CHECK_MATCHING handle it)
                                current_idx <= num_translators; // Force reset in next cycle
                                pair_idx <= 4'b0;
                            end else begin
                                // Not compatible, try next
                                pair_idx <= pair_idx + 1;
                            end
                        end
                    end
                end

                FOUND_MATCHING: begin
                    valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule
