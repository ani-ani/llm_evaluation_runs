module dry_ice_transfer(
    input clk,
    input rst_n,
    input start,
    input [7:0] bottle1_cap,
    input [7:0] bottle2_cap,
    input [7:0] target,
    output reg [2:0] op,
    output reg [1:0] src,
    output reg [1:0] dst,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] BFS       = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] IMPOSSIBLE = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    reg [2:0] state, next_state;

    // BFS state tracking
    reg [7:0] current_b1, current_b2;
    reg [7:0] next_b1, next_b2;
    reg [7:0] parent_b1 [0:999];
    reg [7:0] parent_b2 [0:999];
    reg [9:0] head, tail;
    reg [9:0] move_count;
    reg [9:0] current_move;
    reg [2:0] move_op [0:999];
    reg [1:0] move_src [0:999];
    reg [1:0] move_dst [0:999];

    // Visited matrix (simplified for synthesis)
    reg [7:0] visited_b1 [0:255];
    reg [7:0] visited_b2 [0:255];
    reg [7:0] visited_count;

    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_b1 <= 8'd0;
            current_b2 <= 8'd0;
            next_b1 <= 8'd0;
            next_b2 <= 8'd0;
            head <= 10'd0;
            tail <= 10'd0;
            move_count <= 10'd0;
            current_move <= 10'd0;
            cycle_count <= 10'd0;
            visited_count <= 8'd0;
            
            for (i = 0; i < 1000; i = i + 1) begin
                parent_b1[i] <= 8'd0;
                parent_b2[i] <= 8'd0;
                move_op[i] <= 3'd0;
                move_src[i] <= 2'd0;
                move_dst[i] <= 2'd0;
            end
            
            for (i = 0; i < 256; i = i + 1) begin
                visited_b1[i] <= 8'd0;
                visited_b2[i] <= 8'd0;
            end
            
            op <= 3'd0;
            src <= 2'd0;
            dst <= 2'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize BFS with empty state
                    head <= 10'd0;
                    tail <= 10'd1;
                    move_count <= 10'd0;
                    current_move <= 10'd0;
                    visited_count <= 8'd0;
                    
                    // Start with both bottles empty
                    parent_b1[0] <= 8'd0;
                    parent_b2[0] <= 8'd0;
                    
                    // Mark initial state as visited
                    visited_b1[0] <= 8'd0;
                    visited_b2[0] <= 8'd0;
                    visited_count <= 8'd1;
                    
                    next_state <= BFS;
                end

                BFS: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    
                    if (head < tail && cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 10'd1;
                        
                        // Get current state from queue
                        current_b1 <= parent_b1[head];
                        current_b2 <= parent_b2[head];
                        
                        // Check if we've reached the target
                        if (current_b1 == target || current_b2 == target) begin
                            next_state <= OUTPUT;
                        end else begin
                            // Generate all possible next states
                            // 1. Fill bottle 1
                            next_b1 <= bottle1_cap;
                            next_b2 <= current_b2;
                            
                            if (!is_visited(next_b1, next_b2)) begin
                                parent_b1[tail] <= next_b1;
                                parent_b2[tail] <= next_b2;
                                move_op[tail] <= 3'd0;  // fill
                                move_src[tail] <= 2'd1; // bottle1
                                move_dst[tail] <= 2'd0; // mix
                                tail <= tail + 10'd1;
                                mark_visited(next_b1, next_b2);
                            end
                            
                            // 2. Fill bottle 2
                            next_b1 <= current_b1;
                            next_b2 <= bottle2_cap;
                            
                            if (!is_visited(next_b1, next_b2)) begin
                                parent_b1[tail] <= next_b1;
                                parent_b2[tail] <= next_b2;
                                move_op[tail] <= 3'd0;  // fill
                                move_src[tail] <= 2'd2; // bottle2
                                move_dst[tail] <= 2'd0; // mix
                                tail <= tail + 10'd1;
                                mark_visited(next_b1, next_b2);
                            end
                            
                            // 3. Discard bottle 1
                            next_b1 <= 8'd0;
                            next_b2 <= current_b2;
                            
                            if (!is_visited(next_b1, next_b2)) begin
                                parent_b1[tail] <= next_b1;
                                parent_b2[tail] <= next_b2;
                                move_op[tail] <= 3'd1;  // discard
                                move_src[tail] <= 2'd1; // bottle1
                                move_dst[tail] <= 2'd0; // mix
                                tail <= tail + 10'd1;
                                mark_visited(next_b1, next_b2);
                            end
                            
                            // 4. Discard bottle 2
                            next_b1 <= current_b1;
                            next_b2 <= 8'd0;
                            
                            if (!is_visited(next_b1, next_b2)) begin
                                parent_b1[tail] <= next_b1;
                                parent_b2[tail] <= next_b2;
                                move_op[tail] <= 3'd1;  // discard
                                move_src[tail] <= 2'd2; // bottle2
                                move_dst[tail] <= 2'd0; // mix
                                tail <= tail + 10'd1;
                                mark_visited(next_b1, next_b2);
                            end
                            
                            // 5. Transfer from bottle1 to bottle2
                            if (current_b1 > 8'd0 && current_b2 < bottle2_cap) begin
                                if (current_b1 + current_b2 <= bottle2_cap) begin
                                    next_b1 <= 8'd0;
                                    next_b2 <= current_b1 + current_b2;
                                end else begin
                                    next_b1 <= current_b1 - (bottle2_cap - current_b2);
                                    next_b2 <= bottle2_cap;
                                end
                                
                                if (!is_visited(next_b1, next_b2)) begin
                                    parent_b1[tail] <= next_b1;
                                    parent_b2[tail] <= next_b2;
                                    move_op[tail] <= 3'd2;  // transfer
                                    move_src[tail] <= 2'd1; // bottle1
                                    move_dst[tail] <= 2'd2; // bottle2
                                    tail <= tail + 10'd1;
                                    mark_visited(next_b1, next_b2);
                                end
                            end
                            
                            // 6. Transfer from bottle2 to bottle1
                            if (current_b2 > 8'd0 && current_b1 < bottle1_cap) begin
                                if (current_b1 + current_b2 <= bottle1_cap) begin
                                    next_b1 <= current_b1 + current_b2;
                                    next_b2 <= 8'd0;
                                end else begin
                                    next_b1 <= bottle1_cap;
                                    next_b2 <= current_b2 - (bottle1_cap - current_b1);
                                end
                                
                                if (!is_visited(next_b1, next_b2)) begin
                                    parent_b1[tail] <= next_b1;
                                    parent_b2[tail] <= next_b2;
                                    move_op[tail] <= 3'd2;  // transfer
                                    move_src[tail] <= 2'd2; // bottle2
                                    move_dst[tail] <= 2'd1; // bottle1
                                    tail <= tail + 10'd1;
                                    mark_visited(next_b1, next_b2);
                                end
                            end
                            
                            head <= head + 10'd1;
                            next_state <= BFS;
                        end
                        
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state <= IMPOSSIBLE;
                        end
                    end else begin
                        next_state <= IMPOSSIBLE;
                    end
                end

                OUTPUT: begin
                    if (current_move == 10'd0) begin
                        // Find the move that led to this state
                        for (i = 1; i < tail; i = i + 1) begin
                            if (parent_b1[i] == current_b1 && parent_b2[i] == current_b2) begin
                                current_move <= i;
                                move_count <= i;
                            end
                        end
                    end
                    
                    if (current_move > 10'd0) begin
                        // Output the move
                        op <= move_op[current_move];
                        src <= move_src[current_move];
                        dst <= move_dst[current_move];
                        valid <= 1'b1;
                        
                        // Move to parent state
                        current_b1 <= parent_b1[current_move];
                        current_b2 <= parent_b2[current_move];
                        current_move <= current_move - 10'd1;
                        
                        if (current_move == 10'd0) begin
                            next_state <= DONE;
                        end
                    end else begin
                        next_state <= DONE;
                    end
                end

                IMPOSSIBLE: begin
                    op <= 3'd3;  // impossible
                    src <= 2'd0;
                    dst <= 2'd0;
                    valid <= 1'b1;
                    done <= 1'b0;
                    next_state <= DONE;
                end

                DONE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Helper function to check if state is visited
    function is_visited;
        input [7:0] b1, b2;
        integer j;
        begin
            is_visited = 1'b0;
            for (j = 0; j < visited_count; j = j + 1) begin
                if (visited_b1[j] == b1 && visited_b2[j] == b2) begin
                    is_visited = 1'b1;
                end
            end
        end
    endfunction

    // Helper task to mark state as visited
    task mark_visited;
        input [7:0] b1, b2;
        begin
            visited_b1[visited_count] <= b1;
            visited_b2[visited_count] <= b2;
            visited_count <= visited_count + 8'd1;
        end
    endtask

endmodule