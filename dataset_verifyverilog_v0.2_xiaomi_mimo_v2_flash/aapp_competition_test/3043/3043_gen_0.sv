module treasure_hunter (
    input clk,
    input rst_n,
    input start,
    input [5:0] grid [0:63],
    input [5:0] K,
    output reg [5:0] days,
    output reg [5:0] visited_count,
    output reg done,
    output reg impossible
);

    // States
    localparam IDLE = 0, FIND_S = 1, INIT_DAY = 2, PROCESS_DAY = 3, CHECK_SUCCESS = 4, INCREMENT_DAY = 5, DONE = 6, IMPOSSIBLE = 7;
    
    // Registers
    reg [3:0] state, next_state;
    reg [2:0] scan_r, scan_c;
    reg start_found;
    reg [2:0] start_r, start_c;
    
    // Queues
    reg [2:0] q_next_r [0:63], q_next_c [0:63];
    reg [5:0] q_next_tail;
    
    // Internal Stack for Day Processing (stores: r, c, stamina)
    reg [2:0] stack_r [0:63], stack_c [0:63];
    reg [5:0] stack_s [0:63];
    reg [5:0] stack_ptr;
    
    // Visited flags
    reg [63:0] visited_start; // Visited in current day's expansion
    reg [63:0] visited_next;  // Added to next day queue
    
    // Sub-state for loops
    reg [1:0] sub_state; // 0=Idle/Start, 1=Action, 2=Done/Next
    reg [5:0] loop_idx;  // General purpose index
    reg [2:0] cur_dir;
    reg found_g;
    reg [2:0] cur_r, cur_c;
    reg [5:0] cur_s;
    reg [2:0] nr, nc;
    reg [5:0] cost_val;

    // Combinational Cost Logic
    always @(*) begin
        cost_val = 100;
        if (nr < 8 && nc < 8) begin
            case(grid[{nr, nc}])
                8'h2E: cost_val = 1; // .
                8'h46: cost_val = 2; // F
                8'h4D: cost_val = 3; // M
                default: cost_val = 100;
            endcase
        end
    end

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case(state)
            IDLE: next_state = start ? FIND_S : IDLE;
            FIND_S: next_state = start_found ? INIT_DAY : FIND_S;
            INIT_DAY: next_state = PROCESS_DAY;
            PROCESS_DAY: next_state = (sub_state == 2'h2) ? CHECK_SUCCESS : PROCESS_DAY;
            CHECK_SUCCESS: begin
                if (found_g) next_state = DONE;
                else if (q_next_tail == 6'd0) next_state = IMPOSSIBLE; // Empty next queue
                else next_state = INCREMENT_DAY;
            end
            INCREMENT_DAY: next_state = (sub_state == 2'h0) ? INIT_DAY : INCREMENT_DAY;
            DONE: next_state = DONE;
            IMPOSSIBLE: next_state = IMPOSSIBLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0; impossible <= 0; days <= 0; visited_count <= 0;
            start_found <= 0; q_next_tail <= 0; stack_ptr <= 0;
            sub_state <= 0; found_g <= 0;
            scan_r <= 0; scan_c <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        days <= 0;
                        found_g <= 0;
                        q_next_tail <= 0;
                        visited_next <= 0;
                    end
                end

                FIND_S: begin
                    if (grid[{scan_r, scan_c}] == 8'h53) begin // S
                        start_r <= scan_r;
                        start_c <= scan_c;
                        start_found <= 1;
                    end
                    if (scan_c == 3'd7) begin
                        scan_c <= 0;
                        if (scan_r == 3'd7) scan_r <= 0; else scan_r <= scan_r + 1;
                    end else begin
                        scan_c <= scan_c + 1;
                    end
                end

                INIT_DAY: begin
                    // Reset sub-state
                    sub_state <= 0;
                    // Prepare Stack
                    if (days == 0) begin
                        // Day 0: Start from S
                        stack_r[0] <= start_r;
                        stack_c[0] <= start_c;
                        stack_s[0] <= K;
                        stack_ptr <= 1;
                        visited_start <= 64'b0;
                        visited_start[{start_r, start_c}] <= 1'b1;
                    end else begin
                        // Days > 0: Stack is already loaded by INCREMENT_DAY (via q_next)
                        // We just need to reset visited_start for the new day's exploration
                        visited_start <= 64'b0;
                    end
                    // Reset queue for next day accumulation
                    q_next_tail <= 0;
                    visited_next <= 64'b0;
                end

                PROCESS_DAY: begin
                    // Sub-state 0: POP
                    if (sub_state == 0) begin
                        if (stack_ptr == 0) begin
                            sub_state <= 2; // Done
                        end else begin
                            // Pop
                            stack_ptr <= stack_ptr - 1;
                            cur_r <= stack_r[stack_ptr - 1];
                            cur_c <= stack_c[stack_ptr - 1];
                            cur_s <= stack_s[stack_ptr - 1];
                            cur_dir <= 0;
                            sub_state <= 1;
                        end
                    end
                    // Sub-state 1: PROCESS NEIGHBORS
                    else if (sub_state == 1) begin
                        if (cur_dir < 4) begin
                            // Calculate neighbor
                            case(cur_dir)
                                0: begin nr <= (cur_r > 0) ? cur_r - 1 : 7; nc <= cur_c; end // Wrap or bound? "8x8 grid". Bounds check.
                                1: begin nr <= (cur_r < 7) ? cur_r + 1 : 7; nc <= cur_c; end // Let's use bounds < 8 and >= 0
                                2: begin nr <= cur_r; nc <= (cur_c > 0) ? cur_c - 1 : 7; end
                                3: begin nr <= cur_r; nc <= (cur_c < 7) ? cur_c + 1 : 7; end
                            endcase
                            
                            // Check bounds immediately in comb logic or next cycle? 
                            // Let's do bounds check in next cycle (combine with cost).
                            // We need to read grid. Grid is input.
                            // We can read grid[{nr, nc}].
                            // We need to wait for cost_val.
                            // So let's add a wait cycle or do it all here.
                            // Let's assume `cost_val` is combinational based on `nr`, `nc`.
                            // But `nr`, `nc` are set in this cycle.
                            // So `cost_val` updates in this cycle.
                            // Good.
                            
                            // Check Validity
                            if (nr < 8 && nc < 8) begin
                                if (grid[{nr, nc}] == 8'h47) begin // G
                                    found_g <= 1;
                                    sub_state <= 2; // End immediately (or clear stack)
                                    stack_ptr <= 0; // Force empty to stop fast
                                end else if (grid[{nr, nc}] != 8'h23) begin // Not #
                                    // Valid Move Candidate
                                    if (cost_val <= cur_s) begin // Can move today
                                        if (!visited_start[{nr, nc}]) begin
                                            visited_start[{nr, nc}] <= 1'b1;
                                            // Push to stack
                                            if (stack_ptr < 64) begin
                                                stack_r[stack_ptr] <= nr;
                                                stack_c[stack_ptr] <= nc;
                                                stack_s[stack_ptr] <= cur_s - cost_val;
                                                stack_ptr <= stack_ptr + 1;
                                            end
                                        end
                                    end else begin // Cannot move today -> Next day candidate
                                        if (!visited_next[{nr, nc}]) begin
                                            visited_next[{nr, nc}] <= 1'b1;
                                            // Add to q_next
                                            if (q_next_tail < 64) begin
                                                q_next_r[q_next_tail] <= nr;
                                                q_next_c[q_next_tail] <= nc;
                                                q_next_tail <= q_next_tail + 1;
                                            end
                                        end
                                    end
                                end
                            end
                            
                            cur_dir <= cur_dir + 1;
                        end else begin
                            sub_state <= 0; // Neighbors done, pop next
                        end
                    end
                end

                INCREMENT_DAY: begin
                    // Sub-state 0: Setup Copy
                    if (sub_state == 0) begin
                        days <= days + 1;
                        loop_idx <= 0; // Reuse loop_idx for copying
                        sub_state <= 1;
                        // Also, we need to update visited_count for debugging?
                        // Just count q_next_tail roughly?
                        visited_count <= q_next_tail;
                    end
                    // Sub-state 1: Copy Loop (q_next -> stack) AND Mark visited_start
                    else if (sub_state == 1) begin
                        if (loop_idx < q_next_tail) begin
                            // Copy
                            stack_r[loop_idx] <= q_next_r[loop_idx];
                            stack_c[loop_idx] <= q_next_c[loop_idx];
                            stack_s[loop_idx] <= K;
                            // Mark visited_start so we don't process duplicate start nodes in PROCESS_DAY
                            // (Though unique q_next ensures no dupes, it's safe)
                            // Actually, we need to mark them so we don't re-add them to next_next queue if they are adjacent.
                            // Yes.
                            // Note: visited_start is a reg array. We need to index it.
                            // visited_start[{q_next_r[loop_idx], q_next_c[loop_idx]}] <= 1'b1;
                            // Wait, we can't index arrays with array elements inside always blocks easily in some tools, but standard Verilog allows it.
                            // However, to be safe, we can use a temp variable or just rely on the fact that they are start of day.
                            // If we don't mark them, PROCESS_DAY will see them as 'new' and mark them. 
                            // But if two adjacent nodes are in q_next, one might process the other.
                            // So we MUST mark them.
                            // Let's do it. 
                            // Optimization: We can just set the bit.
                            // visited_start[{q_next_r[loop_idx], q_next_c[loop_idx]}] <= 1'b1; 
                            // This requires a combinational index. 
                            // Let's compute the index.
                            // loop_idx is 6 bit. q_next_r/c are 3 bit.
                            // We'll do it in the next block or combine.
                            
                            // We need to update stack_ptr at the end.
                            // stack_ptr <= q_next_tail.
                            // Let's do it at the end of loop.
                            loop_idx <= loop_idx + 1;
                        end else begin
                            // Done copying
                            stack_ptr <= q_next_tail;
                            // Reset q_next for next iteration
                            q_next_tail <= 0;
                            // Clear visited_next
                            visited_next <= 64'b0;
                            sub_state <= 0; // Signal done to state machine
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                end

                IMPOSSIBLE: begin
                    impossible <= 1;
                    done <= 1;
                end
            endcase
        end
    end
endmodule
