module cow_horse_chase (
    input clk,
    input rst_n,
    input start,
    input [4:0] L,
    input [4:0] A,
    input [4:0] B,
    input [4:0] P,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] DEQUEUE   = 3'd2;
    localparam [3:0] GEN_MOVES = 3'd3;
    localparam [3:0] CHECK_VISIT = 3'd4;
    localparam [3:0] UPDATE    = 3'd5;
    localparam [3:0] DONE      = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Inputs (registered)
    reg [4:0] L_reg, A_reg, B_reg, P_reg;

    // 16x16x16 memory (4096 bits) for visited and distance
    reg [3:0] dist_mem [0:4095]; // 4 bits for distance (0-15)
    reg visited_mem [0:4095];    // 1 bit for visited flag
    reg [12:0] mem_addr;
    reg mem_write;
    wire [3:0] mem_dist_out;
    wire mem_visited_out;

    // Assign memory read outputs
    assign mem_dist_out = dist_mem[mem_addr];
    assign mem_visited_out = visited_mem[mem_addr];

    // FIFO Queue: 128 entries, 15-bit width
    reg [14:0] queue [0:127];
    reg [6:0] head, tail, next_tail;
    reg queue_empty, queue_full;
    reg [14:0] current_state;
    reg [14:0] next_state_temp;

    // Move generation variables
    reg [2:0] move_idx;
    reg [4:0] c1_move, c2_move, h_move;
    reg [4:0] c1_next, c2_next, h_next;
    reg [4:0] c1_temp, c2_temp, h_temp;
    reg signed [4:0] h_offset;
    reg [3:0] capture_time;
    reg [15:0] state_index;
    reg [3:0] dist_check;
    reg [3:0] new_dist;
    reg is_valid_move;
    reg is_target;
    reg found_target;

    // For concurrent simulation (4 states per cycle)
    reg [2:0] sub_state;
    localparam [2:0] SUB_IDLE   = 3'd0;
    localparam [2:0] SUB_GEN_C1 = 3'd1;
    localparam [2:0] SUB_GEN_C2 = 3'd2;
    localparam [2:0] SUB_GEN_H  = 3'd3;
    localparam [2:0] SUB_CHECK  = 3'd4;
    localparam [2:0] SUB_UPDATE = 3'd5;

    // Initialize memory (conceptual - actual reset handled in always block)
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            head <= 7'd0;
            tail <= 7'd0;
            queue_empty <= 1'b1;
            queue_full <= 1'b0;
            mem_write <= 1'b0;
            sub_state <= SUB_IDLE;
            move_idx <= 3'd0;
            found_target <= 1'b0;
            L_reg <= 5'd0;
            A_reg <= 5'd0;
            B_reg <= 5'd0;
            P_reg <= 5'd0;
            // Initialize memory arrays (required for Icarus)
            for (i = 0; i < 4096; i = i + 1) begin
                dist_mem[i] <= 4'd0;
                visited_mem[i] <= 1'b0;
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            mem_write <= 1'b0;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    found_target <= 1'b0;
                    sub_state <= SUB_IDLE;
                    if (start) begin
                        state <= INIT;
                        // Register inputs
                        L_reg <= (L >= 5'd1 && L <= 5'd15) ? L : 5'd15;
                        A_reg <= A;
                        B_reg <= B;
                        P_reg <= P;
                    end
                end

                INIT: begin
                    // Initialize memory and queue
                    if (sub_state == SUB_IDLE) begin
                        // Reset memory arrays
                        for (i = 0; i < 4096; i = i + 1) begin
                            visited_mem[i] <= 1'b0;
                            dist_mem[i] <= 4'd0;
                        end
                        sub_state <= SUB_GEN_C1; // Use as temp state
                        head <= 7'd0;
                        tail <= 7'd0;
                        queue_empty <= 1'b1;
                        queue_full <= 1'b0;
                    end else begin
                        // Enqueue start state
                        if (!queue_full) begin
                            queue[tail] <= {A_reg, B_reg, P_reg};
                            next_tail <= tail + 7'd1;
                            state_index <= {1'b0, A_reg, B_reg, P_reg}; // 0-4095
                            mem_write <= 1'b1;
                            visited_mem[{1'b0, A_reg, B_reg, P_reg}] <= 1'b1;
                            dist_mem[{1'b0, A_reg, B_reg, P_reg}] <= 4'd0;
                            queue_empty <= 1'b0;
                            // Check full
                            if (tail + 7'd1 == head) queue_full <= 1'b1;
                            tail <= tail + 7'd1;
                            sub_state <= SUB_IDLE;
                            state <= DEQUEUE;
                        end
                    end
                end

                DEQUEUE: begin
                    if (queue_empty) begin
                        state <= DONE;
                    end else begin
                        current_state <= queue[head];
                        next_tail <= tail; // Keep tail value
                        move_idx <= 3'd0;
                        sub_state <= SUB_GEN_C1;
                        state <= GEN_MOVES;
                    end
                end

                GEN_MOVES: begin
                    // Concurrent generation: 1 cycle per sub-state
                    case (sub_state)
                        SUB_GEN_C1: begin
                            // Cow 1 moves: -1, 0, +1
                            case (move_idx)
                                3'd0: c1_move <= (current_state[14:10] > 5'd0) ? 5'd1 : 5'd0; // -1
                                3'd1: c1_move <= 5'd0; // Stay
                                3'd2: c1_move <= (current_state[14:10] < L_reg) ? 5'd1 : 5'd0; // +1
                            endcase
                            sub_state <= SUB_GEN_C2;
                            move_idx <= move_idx + 3'd1;
                            if (move_idx >= 3'd2) move_idx <= 3'd0; // Loop 0,1,2
                        end

                        SUB_GEN_C2: begin
                            // Cow 2 moves
                            if (move_idx == 3'd0) begin
                                // Store intermediate c1 result
                                if (current_state[14:10] > 5'd0) c1_temp <= current_state[14:10] - 5'd1;
                                else c1_temp <= current_state[14:10];
                                c2_move <= (current_state[9:5] > 5'd0) ? 5'd1 : 5'd0; // -1
                            end else if (move_idx == 3'd1) begin
                                c1_temp <= current_state[14:10]; // Stay
                                c2_move <= 5'd0; // Stay
                            end else begin
                                c1_temp <= (current_state[14:10] < L_reg) ? current_state[14:10] + 5'd1 : current_state[14:10];
                                c2_move <= (current_state[9:5] < L_reg) ? 5'd1 : 5'd0; // +1
                            end
                            sub_state <= SUB_GEN_H;
                        end

                        SUB_GEN_H: begin
                            // Horse moves: ±1, ±2 (bounded by L)
                            // Use h_offset based on move_idx
                            case (move_idx)
                                3'd0: h_offset <= -5'd2;
                                3'd1: h_offset <= -5'd1;
                                3'd2: h_offset <= 5'd1;
                                default: h_offset <= 5'd2;
                            endcase
                            
                            // Calculate valid cow position
                            if (c1_temp > c2_temp) begin
                                c1_next <= c1_temp;
                                c2_next <= c2_temp;
                            end else begin
                                c1_next <= c2_temp;
                                c2_next <= c1_temp;
                            end
                            
                            // Calculate horse next
                            h_next <= current_state[4:0] + h_offset;
                            
                            // Check bounds
                            is_valid_move <= 1'b0;
                            if ((current_state[4:0] + h_offset) >= 5'd0 && 
                                (current_state[4:0] + h_offset) <= L_reg) begin
                                is_valid_move <= 1'b1;
                            end
                            
                            sub_state <= SUB_CHECK;
                        end

                        SUB_CHECK: begin
                            if (is_valid_move) begin
                                // Check capture: H == C1 or H == C2
                                is_target <= 1'b0;
                                capture_time <= 4'd0;
                                if (h_next == c1_next || h_next == c2_next) begin
                                    is_target <= 1'b1;
                                    // Check distance in memory
                                    state_index <= {1'b0, c1_next, c2_next, h_next};
                                    if (visited_mem[{1'b0, c1_next, c2_next, h_next}]) begin
                                        capture_time <= dist_mem[{1'b0, c1_next, c2_next, h_next}];
                                    end
                                end
                            end
                            sub_state <= SUB_UPDATE;
                        end

                        SUB_UPDATE: begin
                            if (is_valid_move && !is_target) begin
                                // Add to queue if not visited
                                state_index <= {1'b0, c1_next, c2_next, h_next};
                                if (!visited_mem[{1'b0, c1_next, c2_next, h_next}] && !queue_full) begin
                                    queue[tail] <= {c1_next, c2_next, h_next};
                                    tail <= tail + 7'd1;
                                    if (tail + 7'd1 == head) queue_full <= 1'b1;
                                    queue_empty <= 1'b0;
                                    mem_write <= 1'b1;
                                    visited_mem[{1'b0, c1_next, c2_next, h_next}] <= 1'b1;
                                    dist_mem[{1'b0, c1_next, c2_next, h_next}] <= mem_dist_out + 4'd1;
                                end
                            end else if (is_valid_move && is_target && !found_target) begin
                                // Found capture
                                found_target <= 1'b1;
                                result <= {4'd0, capture_time} + 8'd1; // +1 for current move
                            end

                            // Generate next move or finish
                            if (move_idx < 3'd3) begin
                                sub_state <= SUB_GEN_C1;
                            end else begin
                                // Finished generating moves for this state
                                if (found_target) begin
                                    state <= DONE;
                                end else begin
                                    // Dequeue next
                                    if (head != tail) begin
                                        head <= head + 7'd1;
                                        queue_full <= 1'b0;
                                        if (head + 7'd1 == tail) queue_empty <= 1'b1;
                                    end
                                    state <= DEQUEUE;
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                result <= 8'd0; // Timeout
                state <= DONE;
            end
        end
    end

endmodule