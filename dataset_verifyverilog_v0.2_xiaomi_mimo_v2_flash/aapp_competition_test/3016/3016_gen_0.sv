module timmy_counter(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_balls_total,
    input [2:0] num_colors,
    input [3:0] color_counts [0:7],
    input [2:0] restricted_count,
    input [2:0] restricted_colors [0:7],
    input [2:0] sequence_len,
    input [2:0] sequence_colors [0:7],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_COLORS = 8;
    localparam STACK_DEPTH = 20;

    // States
    localparam STATE_IDLE = 0;
    localparam STATE_INIT = 1;
    localparam STATE_LOAD_STATE = 2;
    localparam STATE_CHECK_BASE = 3;
    localparam STATE_CHECK_MEMO = 4;
    localparam STATE_CHECK_MEMO_WAIT = 5;
    localparam STATE_SEARCH_CHILD = 6;
    localparam STATE_PUSH = 7;
    localparam STATE_POP_ACCUM = 8;

    // Storage for Input Registers
    reg [3:0] r_num_balls_total;
    reg [2:0] r_num_colors;
    reg [3:0] r_color_counts [0:7];
    reg [2:0] r_restricted_count;
    reg [2:0] r_restricted_colors [0:7];
    reg [2:0] r_sequence_len;
    reg [2:0] r_sequence_colors [0:7];

    // Stack Memory
    reg [31:0] stack_counts [0:STACK_DEPTH-1]; // Packed: {count[7], ..., count[0]}
    reg [31:0] stack_acc [0:STACK_DEPTH-1];    // Accumulator for children results
    reg [15:0] stack_info [0:STACK_DEPTH-1];   // Packed: {last[3:0], match[3:0], sum[3:0], next[3:0]}
    reg [4:0] stack_ptr;                       // Points to next free slot

    // Working Registers
    reg [3:0] cur_counts [0:7];                // Unpacked current counts
    reg [3:0] cur_last_color;
    reg [3:0] cur_match;
    reg [3:0] cur_sum;
    reg [3:0] cur_idx;                         // Iterator in SEARCH_CHILD

    // Memoization RAM
    reg [32:0] memo_ram [0:255];               // {valid[0], value[31:0]}
    reg [7:0] memo_addr;
    reg memo_wren;
    reg [32:0] memo_wdata;
    wire [32:0] memo_rdata;

    // Temporary Return Value
    reg [31:0] return_val;

    // State Register
    reg [3:0] current_state;

    // Combinational RAM Read
    assign memo_rdata = memo_ram[memo_addr];

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            done <= 1'b0;
            result <= 32'd0;
            stack_ptr <= 0;
            memo_wren <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Store inputs
                        r_num_balls_total <= num_balls_total;
                        r_num_colors <= num_colors;
                        r_restricted_count <= restricted_count;
                        r_sequence_len <= sequence_len;
                        // Unpack inputs to registers for easier access
                        for (integer i = 0; i < 8; i++) begin
                            r_color_counts[i] <= color_counts[i];
                            r_restricted_colors[i] <= restricted_colors[i];
                            r_sequence_colors[i] <= sequence_colors[i];
                        end
                        current_state <= STATE_INIT;
                    end
                end

                STATE_INIT: begin
                    // Push Root Node
                    // Counts: Pack inputs
                    stack_counts[0] <= {
                        r_color_counts[7], r_color_counts[6], r_color_counts[5], r_color_counts[4],
                        r_color_counts[3], r_color_counts[2], r_color_counts[1], r_color_counts[0]
                    };
                    // Info: last=15 (none), match=0, sum=0, next=0
                    stack_info[0] <= {4'd15, 4'd0, 4'd0, 4'd0};
                    // Acc: 0
                    stack_acc[0] <= 32'd0;
                    
                    stack_ptr <= 1;
                    current_state <= STATE_LOAD_STATE;
                end

                STATE_LOAD_STATE: begin
                    memo_wren <= 1'b0; // Reset write enable
                    if (stack_ptr == 0) begin
                        // Should theoretically only happen if root returns correctly
                        current_state <= STATE_IDLE;
                    end else begin
                        // Unpack from Stack to Working Registers
                        // Stack index is stack_ptr - 1
                        {cur_counts[7], cur_counts[6], cur_counts[5], cur_counts[4],
                         cur_counts[3], cur_counts[2], cur_counts[1], cur_counts[0]} <= stack_counts[stack_ptr - 1];
                        {cur_last_color, cur_match, cur_sum, cur_idx} <= stack_info[stack_ptr - 1];
                        current_state <= STATE_CHECK_BASE;
                    end
                end

                STATE_CHECK_BASE: begin
                    // Check if total balls reached
                    if (cur_sum == r_num_balls_total) begin
                        // Base Case: Valid path found
                        return_val <= 32'd1;
                        // Write to Memo (Leaf Node)
                        memo_addr <= (cur_match ^ cur_last_color ^ cur_counts[0] ^ cur_counts[1] ^ cur_counts[2] ^ cur_counts[3] ^ cur_counts[4] ^ cur_counts[5] ^ cur_counts[6] ^ cur_counts[7]);
                        memo_wdata <= {1'b1, 32'd1};
                        memo_wren <= 1'b1;
                        current_state <= STATE_POP_ACCUM;
                    end else begin
                        current_state <= STATE_CHECK_MEMO;
                    end
                end

                STATE_CHECK_MEMO: begin
                    // Calculate Memo Address (Hash)
                    memo_addr <= (cur_match ^ cur_last_color ^ cur_counts[0] ^ cur_counts[1] ^ cur_counts[2] ^ cur_counts[3] ^ cur_counts[4] ^ cur_counts[5] ^ cur_counts[6] ^ cur_counts[7]);
                    current_state <= STATE_CHECK_MEMO_WAIT;
                end

                STATE_CHECK_MEMO_WAIT: begin
                    // Synchronous RAM read result available
                    if (memo_rdata[32]) begin
                        // Hit
                        return_val <= memo_rdata[31:0];
                        current_state <= STATE_POP_ACCUM;
                    end else begin
                        // Miss - Start searching children
                        cur_idx <= 4'd0; // Initialize iterator
                        current_state <= STATE_SEARCH_CHILD;
                    end
                end

                STATE_SEARCH_CHILD: begin
                    // Iterate cur_idx to find valid child
                    if (cur_idx >= r_num_colors) begin
                        // Exhausted all colors. Node computation complete.
                        return_val <= stack_acc[stack_ptr - 1];
                        // Write to Memo
                        memo_wdata <= {1'b1, stack_acc[stack_ptr - 1]};
                        memo_wren <= 1'b1;
                        current_state <= STATE_POP_ACCUM;
                    end else begin
                        // Check if cur_idx is a valid move
                        // 1. Count check
                        // 2. Adjacency check
                        // 3. Sequence check
                        
                        reg is_valid_move;
                        reg [3:0] eff_match;
                        reg is_last_r, is_next_r;
                        integer k;
                        
                        is_valid_move = 1'b0;
                        
                        // Check Count
                        if (cur_counts[cur_idx] > 0) begin
                            // Check Adjacency
                            is_last_r = 1'b0;
                            is_next_r = 1'b0;
                            if (r_restricted_count > 0 && cur_last_color < r_num_colors) begin
                                for (k = 0; k < 8; k++) begin
                                    if (k < r_restricted_count && r_restricted_colors[k] == cur_last_color) is_last_r = 1'b1;
                                end
                                for (k = 0; k < 8; k++) begin
                                    if (k < r_restricted_count && r_restricted_colors[k] == cur_idx) is_next_r = 1'b1;
                                end
                            end
                            
                            if (!(is_last_r && is_next_r)) begin
                                // Check Sequence
                                is_valid_move = 1'b1; // Default valid unless constrained by forced match
                                
                                if (r_sequence_len > 0) begin
                                    eff_match = (cur_match == r_sequence_len) ? 0 : cur_match;
                                    if (eff_match > 0) begin
                                        // Forced to match sequence_colors[eff_match]
                                        if (cur_idx[2:0] != r_sequence_colors[eff_match]) begin
                                            is_valid_move = 1'b0;
                                        end
                                    end
                                    // If eff_match == 0, any color is allowed (free start)
                                end
                            end
                        end
                        
                        if (is_valid_move) begin
                            // Found valid child
                            // Update current node's 'next_child' index (increment it) on stack
                            stack_info[stack_ptr - 1] <= {cur_last_color, cur_match, cur_sum, cur_idx + 1};
                            // Go push the child
                            current_state <= STATE_PUSH;
                        end else begin
                            // Invalid, try next color
                            cur_idx <= cur_idx + 1;
                            // Stay in SEARCH_CHILD (Loop)
                            // Note: We don't update stack_info here, only when we find a valid child or finish
                            current_state <= STATE_SEARCH_CHILD;
                        end
                    end
                end

                STATE_PUSH: begin
                    // Create child node
                    // Parent info (at stack_ptr-1) has been updated to increment next_child in previous state
                    
                    // Child Counts: Parent counts - 1 at cur_idx
                    stack_counts[stack_ptr] <= {
                        cur_counts[7] - (cur_idx == 7), cur_counts[6] - (cur_idx == 6),
                        cur_counts[5] - (cur_idx == 5), cur_counts[4] - (cur_idx == 4),
                        cur_counts[3] - (cur_idx == 3), cur_counts[2] - (cur_idx == 2),
                        cur_counts[1] - (cur_idx == 1), cur_counts[0] - (cur_idx == 0)
                    };
                    
                    // Child Info
                    // Calculate Next Match
                    reg [3:0] next_match;
                    reg [3:0] eff_match_push;
                    
                    eff_match_push = (cur_match == r_sequence_len) ? 0 : cur_match;
                    
                    if (r_sequence_len > 0) begin
                        if (eff_match_push > 0) begin
                            next_match = eff_match_push + 1;
                        end else begin
                            if (cur_idx[2:0] == r_sequence_colors[0]) next_match = 1;
                            else next_match = 0;
                        end
                        if (next_match == r_sequence_len) next_match = r_sequence_len; // Keep done state
                    end else begin
                        next_match = 0;
                    end
                    
                    // Pack info: last=cur_idx, match=next_match, sum=cur_sum+1, next=0
                    stack_info[stack_ptr] <= {cur_idx, next_match, cur_sum + 1, 4'd0};
                    
                    // Child Acc: 0
                    stack_acc[stack_ptr] <= 32'd0;
                    
                    // Increment Stack Pointer
                    stack_ptr <= stack_ptr + 1;
                    
                    // Process Child
                    current_state <= STATE_LOAD_STATE;
                end

                STATE_POP_ACCUM: begin
                    // 'return_val' holds the value to return to the parent (or final result)
                    
                    if (stack_ptr == 1) begin
                        // Root returning
                        result <= return_val; // return_val is already modulo MOD
                        done <= 1'b1;
                        current_state <= STATE_IDLE;
                        stack_ptr <= 0; // Clean up
                    end else begin
                        // Pop current node (decrement pointer)
                        stack_ptr <= stack_ptr - 1;
                        // Add return_val to new top (parent) accumulator
                        stack_acc[stack_ptr - 2] <= (stack_acc[stack_ptr - 2] + return_val) % MOD;
                        // Continue processing parent (it might have more children)
                        current_state <= STATE_LOAD_STATE;
                    end
                end
                
                default: current_state <= STATE_IDLE;
            endcase
        end
    end

endmodule
