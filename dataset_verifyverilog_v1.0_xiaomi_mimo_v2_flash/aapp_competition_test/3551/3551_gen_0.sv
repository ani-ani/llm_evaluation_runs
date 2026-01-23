module dry_ice_transfer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] bottle1_cap,
    input wire [7:0] bottle2_cap,
    input wire [7:0] target,
    output reg [2:0] op,
    output reg [1:0] src,
    output reg [1:0] dst,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_INPUT = 3'd1;
    localparam [2:0] INIT_BFS    = 3'd2;
    localparam [2:0] GENERATE    = 3'd3;
    localparam [2:0] OUTPUT_OP   = 3'd4;
    localparam [2:0] FINISH      = 3'd5;
    localparam [2:0] IMPOSSIBLE  = 3'd6;

    // Operation codes
    localparam [2:0] OP_FILL    = 3'd0;
    localparam [2:0] OP_DISCARD = 3'd1;
    localparam [2:0] OP_TRANSFER = 3'd2;
    localparam [2:0] OP_IMPOSSIBLE = 3'd3;
    localparam [2:0] OP_DONE    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_a, current_b;  // Current amounts in bottles
    reg [7:0] next_a, next_b;
    reg [7:0] cap1, cap2, tgt;
    reg [2:0] move_type;  // 0=fill1, 1=fill2, 2=discard1, 3=discard2, 4=transfer1to2, 5=transfer2to1
    reg [2:0] move_count;
    reg [7:0] step_counter;
    localparam [7:0] MAX_STEPS = 8'd100;
    localparam [2:0] MAX_MOVES = 3'd7;
    
    // Visited array for BFS - using packed array for compatibility
    // 8x8 = 64 entries max for bottle capacities up to 7
    // We'll use a bit vector for visited states
    reg [63:0] visited;
    reg [7:0] queue_a [0:63];
    reg [7:0] queue_b [0:63];
    reg [5:0] queue_head;
    reg [5:0] queue_tail;
    reg [5:0] prev_index [0:63];
    reg [2:0] move_done [0:63];
    
    // Helper: encode state to index
    function [5:0] encode_state;
        input [7:0] a;
        input [7:0] b;
        input [7:0] cap1_in;
        input [7:0] cap2_in;
        begin
            // Simple encoding: a * (cap2+1) + b
            encode_state = (a * (cap2_in + 8'd1)) + b;
        end
    endfunction
    
    // Helper: get operation from move type
    function [2:0] get_op;
        input [2:0] mtype;
        begin
            case (mtype)
                3'd0: get_op = OP_FILL;      // fill bottle1
                3'd1: get_op = OP_FILL;      // fill bottle2
                3'd2: get_op = OP_DISCARD;   // discard bottle1
                3'd3: get_op = OP_DISCARD;   // discard bottle2
                3'd4: get_op = OP_TRANSFER;  // transfer 1->2
                3'd5: get_op = OP_TRANSFER;  // transfer 2->1
                default: get_op = OP_FILL;
            endcase
        end
    endfunction
    
    // Helper: get source bottle
    function [1:0] get_src;
        input [2:0] mtype;
        begin
            case (mtype)
                3'd0: get_src = 2'd1;  // fill bottle1
                3'd1: get_src = 2'd2;  // fill bottle2
                3'd2: get_src = 2'd1;  // discard bottle1
                3'd3: get_src = 2'd2;  // discard bottle2
                3'd4: get_src = 2'd1;  // transfer 1->2
                3'd5: get_src = 2'd2;  // transfer 2->1
                default: get_src = 2'd0;
            endcase
        end
    endfunction
    
    // Helper: get destination bottle
    function [1:0] get_dst;
        input [2:0] mtype;
        begin
            case (mtype)
                3'd0: get_dst = 2'd1;  // fill bottle1
                3'd1: get_dst = 2'd2;  // fill bottle2
                3'd2: get_dst = 2'd0;  // discard bottle1 (to mix)
                3'd3: get_dst = 2'd0;  // discard bottle2 (to mix)
                3'd4: get_dst = 2'd2;  // transfer 1->2
                3'd5: get_dst = 2'd1;  // transfer 2->1
                default: get_dst = 2'd0;
            endcase
        end
    endfunction
    
    // Helper: compute next state after move
    function [15:0] apply_move;
        input [7:0] a_in;
        input [7:0] b_in;
        input [2:0] mtype;
        input [7:0] c1;
        input [7:0] c2;
        reg [7:0] new_a, new_b;
        begin
            case (mtype)
                3'd0: begin new_a = c1; new_b = b_in; end  // fill1
                3'd1: begin new_a = a_in; new_b = c2; end  // fill2
                3'd2: begin new_a = 8'd0; new_b = b_in; end  // discard1
                3'd3: begin new_a = a_in; new_b = 8'd0; end  // discard2
                3'd4: begin  // transfer 1->2
                    if (a_in + b_in <= c2) begin
                        new_a = 8'd0;
                        new_b = a_in + b_in;
                    end else begin
                        new_b = c2;
                        new_a = a_in + b_in - c2;
                    end
                end
                3'd5: begin  // transfer 2->1
                    if (a_in + b_in <= c1) begin
                        new_a = a_in + b_in;
                        new_b = 8'd0;
                    end else begin
                        new_a = c1;
                        new_b = a_in + b_in - c1;
                    end
                end
                default: begin new_a = a_in; new_b = b_in; end
            endcase
            apply_move = {new_a, new_b};
        end
    endfunction

    // Forward declaration for path reconstruction
    reg [5:0] path_indices [0:63];
    reg [2:0] path_moves [0:63];
    reg [2:0] path_len;
    reg [5:0] current_idx;
    reg [2:0] path_step;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            op <= 3'd0;
            src <= 2'd0;
            dst <= 2'd0;
            valid <= 1'b0;
            done <= 1'b0;
            current_a <= 8'd0;
            current_b <= 8'd0;
            cap1 <= 8'd0;
            cap2 <= 8'd0;
            tgt <= 8'd0;
            move_type <= 3'd0;
            move_count <= 3'd0;
            step_counter <= 8'd0;
            visited <= 64'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            path_len <= 3'd0;
            current_idx <= 6'd0;
            path_step <= 3'd0;
            // Initialize arrays
            begin : init_arrays
                integer i;
                for (i = 0; i < 64; i = i + 1) begin
                    queue_a[i] <= 8'd0;
                    queue_b[i] <= 8'd0;
                    prev_index[i] <= 6'd0;
                    move_done[i] <= 3'd0;
                    path_indices[i] <= 6'd0;
                    path_moves[i] <= 3'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    op <= 3'd0;
                    src <= 2'd0;
                    dst <= 2'd0;
                    move_count <= 3'd0;
                    step_counter <= 8'd0;
                    if (start) begin
                        state <= CHECK_INPUT;
                        cap1 <= bottle1_cap;
                        cap2 <= bottle2_cap;
                        tgt <= target;
                    end
                end
                
                CHECK_INPUT: begin
                    // Check if target is valid
                    if (tgt == 8'd0) begin
                        state <= OUTPUT_OP;
                        op <= OP_DONE;
                        path_len <= 3'd0;
                        path_step <= 3'd0;
                    end else if (tgt > cap1 && tgt > cap2) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        state <= INIT_BFS;
                    end
                end
                
                INIT_BFS: begin
                    // Initialize BFS
                    visited <= 64'd0;
                    queue_head <= 6'd0;
                    queue_tail <= 6'd1;
                    queue_a[0] <= 8'd0;
                    queue_b[0] <= 8'd0;
                    prev_index[0] <= 6'd0;
                    move_done[0] <= 3'd7;  // Invalid move for start
                    visited[encode_state(0, 0, cap1, cap2)] <= 1'b1;
                    state <= GENERATE;
                    step_counter <= 8'd0;
                end
                
                GENERATE: begin
                    if (queue_head >= queue_tail || step_counter >= MAX_STEPS) begin
                        // BFS complete or timeout
                        state <= IMPOSSIBLE;
                    end else begin
                        // Dequeue
                        current_a <= queue_a[queue_head];
                        current_b <= queue_b[queue_head];
                        state <= OUTPUT_OP;
                        move_type <= 3'd0;
                    end
                end
                
                OUTPUT_OP: begin
                    if (path_step < path_len) begin
                        // Outputting path moves
                        op <= get_op(path_moves[path_step]);
                        src <= get_src(path_moves[path_step]);
                        dst <= get_dst(path_moves[path_step]);
                        valid <= 1'b1;
                        path_step <= path_step + 3'd1;
                        if (path_step + 3'd1 == path_len) begin
                            state <= FINISH;
                        end
                    end else if (current_a == tgt || current_b == tgt) begin
                        // Found target! Reconstruct path
                        if (path_len == 3'd0) begin
                            // First discovery
                            path_len <= 3'd1;
                            path_moves[0] <= 3'd6;  // Mark as found
                            state <= FINISH;
                        end else begin
                            state <= FINISH;
                        end
                        op <= OP_DONE;
                        valid <= 1'b1;
                    end else if (move_type < MAX_MOVES) begin
                        // Generate moves
                        valid <= 1'b0;
                        begin : generate_move
                            reg [7:0] new_a_val, new_b_val;
                            reg [5:0] state_idx;
                            reg visited_bit;
                            new_a_val = apply_move[15:8];
                            new_b_val = apply_move[7:0];
                            new_a_val = apply_move(current_a, current_b, move_type, cap1, cap2)[15:8];
                            new_b_val = apply_move(current_a, current_b, move_type, cap1, cap2)[7:0];
                            state_idx = encode_state(new_a_val, new_b_val, cap1, cap2);
                            visited_bit = visited[state_idx];
                            
                            if (!visited_bit && new_a_val <= cap1 && new_b_val <= cap2) begin
                                // Add to queue
                                queue_a[queue_tail] <= new_a_val;
                                queue_b[queue_tail] <= new_b_val;
                                prev_index[queue_tail] <= queue_head;
                                move_done[queue_tail] <= move_type;
                                visited[state_idx] <= 1'b1;
                                queue_tail <= queue_tail + 6'd1;
                                
                                // Check if this is target
                                if (new_a_val == tgt || new_b_val == tgt) begin
                                    // Reconstruct path
                                    path_len <= 3'd0;
                                    current_idx <= queue_tail;
                                    state <= FINISH;
                                    path_step <= 3'd0;
                                end
                            end
                        end
                        move_type <= move_type + 3'd1;
                    end else begin
                        // All moves processed, go to next state in queue
                        queue_head <= queue_head + 6'd1;
                        move_type <= 3'd0;
                        step_counter <= step_counter + 8'd1;
                        state <= GENERATE;
                    end
                end
                
                FINISH: begin
                    if (path_step < path_len) begin
                        // Continue outputting path
                        valid <= 1'b1;
                        op <= get_op(path_moves[path_step]);
                        src <= get_src(path_moves[path_step]);
                        dst <= get_dst(path_moves[path_step]);
                        path_step <= path_step + 3'd1;
                        if (path_step + 3'd1 == path_len) begin
                            done <= 1'b1;
                        end
                    end else begin
                        // Reconstruct if needed
                        if (current_idx != 6'd0) begin
                            path_moves[path_len] <= move_done[current_idx];
                            path_len <= path_len + 3'd1;
                            current_idx <= prev_index[current_idx];
                        end else begin
                            // Path complete
                            if (path_len == 3'd0) begin
                                // Found at start
                                op <= OP_DONE;
                                valid <= 1'b1;
                            end
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end
                
                IMPOSSIBLE: begin
                    op <= OP_IMPOSSIBLE;
                    src <= 2'd0;
                    dst <= 2'd0;
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule