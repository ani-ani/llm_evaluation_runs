module min_swaps (
    input clk,
    input rst_n,
    input start,
    input [3:0] perm [0:3],
    input [3:0] swap_a [0:5],
    input [3:0] swap_b [0:5],
    input [2:0] num_swaps,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] GEN = 3'd3;
    localparam [2:0] PROCESS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] queue_state [0:15]; // Max 16 states
    reg [3:0] queue_depth [0:15]; // Depth for each state
    reg [3:0] visited [0:15]; // Track visited states
    reg [3:0] front, rear, count;
    reg [2:0] current_depth;
    reg [3:0] temp_state [0:3];
    reg [2:0] swap_idx;
    reg [3:0] new_state_val;
    reg [3:0] swap_temp;
    reg found_flag;
    reg [2:0] cycle_counter;
    localparam [2:0] MAX_CYCLES = 3'd6;

    // Helper logic to encode state (permutation -> 4-bit ID)
    // 0000=1234, 0001=1243, 0010=1324, 0011=1342, 0100=1423, 0101=1432
    // 0110=2134, 0111=2143, 1000=2314, 1001=2341, 1010=2413, 1011=2431
    // 1100=3124, 1101=3142, 1110=3214, 1111=3241 (partial mapping for N=4)
    wire [3:0] encode_out;
    assign encode_out = (perm[0]==4'd1 && perm[1]==4'd2 && perm[2]==4'd3 && perm[3]==4'd4) ? 4'd0 : 
                        (perm[0]==4'd1 && perm[1]==4'd2 && perm[2]==4'd4 && perm[3]==4'd3) ? 4'd1 :
                        (perm[0]==4'd1 && perm[1]==4'd3 && perm[2]==4'd2 && perm[3]==4'd4) ? 4'd2 :
                        (perm[0]==4'd1 && perm[1]==4'd3 && perm[2]==4'd4 && perm[3]==4'd3) ? 4'd3 :
                        (perm[0]==4'd1 && perm[1]==4'd4 && perm[2]==4'd2 && perm[3]==4'd3) ? 4'd4 :
                        (perm[0]==4'd1 && perm[1]==4'd4 && perm[2]==4'd3 && perm[3]==4'd2) ? 4'd5 :
                        (perm[0]==4'd2 && perm[1]==4'd1 && perm[2]==4'd3 && perm[3]==4'd4) ? 4'd6 :
                        (perm[0]==4'd2 && perm[1]==4'd1 && perm[2]==4'd4 && perm[3]==4'd3) ? 4'd7 :
                        (perm[0]==4'd2 && perm[1]==4'd3 && perm[2]==4'd1 && perm[3]==4'd4) ? 4'd8 :
                        (perm[0]==4'd2 && perm[1]==4'd3 && perm[2]==4'd4 && perm[3]==4'd1) ? 4'd9 :
                        (perm[0]==4'd2 && perm[1]==4'd4 && perm[2]==4'd1 && perm[3]==4'd3) ? 4'd10 :
                        (perm[0]==4'd2 && perm[1]==4'd4 && perm[2]==4'd3 && perm[3]==4'd1) ? 4'd11 :
                        (perm[0]==4'd3 && perm[1]==4'd1 && perm[2]==4'd2 && perm[3]==4'd4) ? 4'd12 :
                        (perm[0]==4'd3 && perm[1]==4'd1 && perm[2]==4'd4 && perm[3]==4'd2) ? 4'd13 :
                        (perm[0]==4'd3 && perm[1]==4'd2 && perm[2]==4'd1 && perm[3]==4'd4) ? 4'd14 :
                        4'd15;

    // Helper for unencoding (for queue gen)
    reg [3:0] u_val;
    always @(*) begin
        case(queue_state[front])
            4'd0: u_val = 4'd0; // 1234
            4'd1: u_val = 4'd1; // 1243
            4'd2: u_val = 4'd2; // 1324
            4'd3: u_val = 4'd3; // 1342
            4'd4: u_val = 4'd4; // 1423
            4'd5: u_val = 4'd5; // 1432
            4'd6: u_val = 4'd6; // 2134
            4'd7: u_val = 4'd7; // 2143
            4'd8: u_val = 4'd8; // 2314
            4'd9: u_val = 4'd9; // 2341
            4'd10: u_val = 4'd10; // 2413
            4'd11: u_val = 4'd11; // 2431
            4'd12: u_val = 4'd12; // 3124
            4'd13: u_val = 4'd13; // 3142
            4'd14: u_val = 4'd14; // 3214
            4'd15: u_val = 4'd15; // 3241
            default: u_val = 4'd0;
        endcase
    end

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            front <= 4'd0;
            rear <= 4'd0;
            count <= 4'd0;
            current_depth <= 3'd0;
            swap_idx <= 3'd0;
            cycle_counter <= 3'd0;
            found_flag <= 1'b0;
            // Initialize visited
            visited[0] <= 1'b0; visited[1] <= 1'b0; visited[2] <= 1'b0; visited[3] <= 1'b0;
            visited[4] <= 1'b0; visited[5] <= 1'b0; visited[6] <= 1'b0; visited[7] <= 1'b0;
            visited[8] <= 1'b0; visited[9] <= 1'b0; visited[10] <= 1'b0; visited[11] <= 1'b0;
            visited[12] <= 1'b0; visited[13] <= 1'b0; visited[14] <= 1'b0; visited[15] <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        // Input already available on perm, capture to temp_state for INIT
                        temp_state[0] <= perm[0];
                        temp_state[1] <= perm[1];
                        temp_state[2] <= perm[2];
                        temp_state[3] <= perm[3];
                    end
                end
                INIT: begin
                    // Reset queue and visited
                    front <= 4'd0;
                    rear <= 4'd0;
                    count <= 4'd0;
                    current_depth <= 3'd0;
                    found_flag <= 1'b0;
                    visited[0] <= 1'b0; visited[1] <= 1'b0; visited[2] <= 1'b0; visited[3] <= 1'b0;
                    visited[4] <= 1'b0; visited[5] <= 1'b0; visited[6] <= 1'b0; visited[7] <= 1'b0;
                    visited[8] <= 1'b0; visited[9] <= 1'b0; visited[10] <= 1'b0; visited[11] <= 1'b0;
                    visited[12] <= 1'b0; visited[13] <= 1'b0; visited[14] <= 1'b0; visited[15] <= 1'b0;
                    
                    // Push start state
                    queue_state[0] <= encode_out;
                    queue_depth[0] <= 4'd0;
                    visited[encode_out] <= 1'b1;
                    rear <= 4'd1;
                    count <= 4'd1;
                    result <= 4'd15; // Max depth init
                end
                CHECK: begin
                    if (count == 4'd0 || cycle_counter >= MAX_CYCLES) begin
                        // Queue empty or timeout
                        found_flag <= 1'b1;
                    end else begin
                        // Check if current state is sorted (ID=0)
                        if (queue_state[front] == 4'd0) begin
                            result <= queue_depth[front];
                            found_flag <= 1'b1;
                        end else begin
                            // Prepare generation
                            swap_idx <= 3'd0;
                        end
                    end
                end
                GEN: begin
                    // Generate new state by applying swap
                    if (swap_idx < num_swaps) begin
                        // Decode current state to temp_state for swapping
                        case(queue_state[front])
                            4'd0: begin temp_state[0]<=4'd1; temp_state[1]<=4'd2; temp_state[2]<=4'd3; temp_state[3]<=4'd4; end
                            4'd1: begin temp_state[0]<=4'd1; temp_state[1]<=4'd2; temp_state[2]<=4'd4; temp_state[3]<=4'd3; end
                            4'd2: begin temp_state[0]<=4'd1; temp_state[1]<=4'd3; temp_state[2]<=4'd2; temp_state[3]<=4'd4; end
                            4'd3: begin temp_state[0]<=4'd1; temp_state[1]<=4'd3; temp_state[2]<=4'd4; temp_state[3]<=4'd3; end
                            4'd4: begin temp_state[0]<=4'd1; temp_state[1]<=4'd4; temp_state[2]<=4'd2; temp_state[3]<=4'd3; end
                            4'd5: begin temp_state[0]<=4'd1; temp_state[1]<=4'd4; temp_state[2]<=4'd3; temp_state[3]<=4'd2; end
                            4'd6: begin temp_state[0]<=4'd2; temp_state[1]<=4'd1; temp_state[2]<=4'd3; temp_state[3]<=4'd4; end
                            4'd7: begin temp_state[0]<=4'd2; temp_state[1]<=4'd1; temp_state[2]<=4'd4; temp_state[3]<=4'd3; end
                            4'd8: begin temp_state[0]<=4'd2; temp_state[1]<=4'd3; temp_state[2]<=4'd1; temp_state[3]<=4'd4; end
                            4'd9: begin temp_state[0]<=4'd2; temp_state[1]<=4'd3; temp_state[2]<=4'd4; temp_state[3]<=4'd1; end
                            4'd10: begin temp_state[0]<=4'd2; temp_state[1]<=4'd4; temp_state[2]<=4'd1; temp_state[3]<=4'd3; end
                            4'd11: begin temp_state[0]<=4'd2; temp_state[1]<=4'd4; temp_state[2]<=4'd3; temp_state[3]<=4'd1; end
                            4'd12: begin temp_state[0]<=4'd3; temp_state[1]<=4'd1; temp_state[2]<=4'd2; temp_state[3]<=4'd4; end
                            4'd13: begin temp_state[0]<=4'd3; temp_state[1]<=4'd1; temp_state[2]<=4'd4; temp_state[3]<=4'd2; end
                            4'd14: begin temp_state[0]<=4'd3; temp_state[1]<=4'd2; temp_state[2]<=4'd1; temp_state[3]<=4'd4; end
                            4'd15: begin temp_state[0]<=4'd3; temp_state[1]<=4'd2; temp_state[2]<=4'd4; temp_state[3]<=4'd1; end
                        endcase
                        
                        // Apply swap
                        swap_temp <= temp_state[swap_a[swap_idx]];
                        temp_state[swap_a[swap_idx]] <= temp_state[swap_b[swap_idx]];
                        temp_state[swap_b[swap_idx]] <= swap_temp;
                    end
                end
                PROCESS: begin
                    // Encode new state and add to queue if not visited
                    if (swap_idx < num_swaps) begin
                        // Encode temp_state
                        // (Simplified encoding logic for generated state)
                        // Assuming same mapping as input
                        new_state_val <= 4'd0; // Default fallback
                        if (temp_state[0]==4'd1 && temp_state[1]==4'd2 && temp_state[2]==4'd3 && temp_state[3]==4'd4) new_state_val <= 4'd0;
                        else if (temp_state[0]==4'd1 && temp_state[1]==4'd2 && temp_state[2]==4'd4 && temp_state[3]==4'd3) new_state_val <= 4'd1;
                        else if (temp_state[0]==4'd1 && temp_state[1]==4'd3 && temp_state[2]==4'd2 && temp_state[3]==4'd4) new_state_val <= 4'd2;
                        else if (temp_state[0]==4'd1 && temp_state[1]==4'd3 && temp_state[2]==4'd4 && temp_state[3]==4'd3) new_state_val <= 4'd3;
                        else if (temp_state[0]==4'd1 && temp_state[1]==4'd4 && temp_state[2]==4'd2 && temp_state[3]==4'd3) new_state_val <= 4'd4;
                        else if (temp_state[0]==4'd1 && temp_state[1]==4'd4 && temp_state[2]==4'd3 && temp_state[3]==4'd2) new_state_val <= 4'd5;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd1 && temp_state[2]==4'd3 && temp_state[3]==4'd4) new_state_val <= 4'd6;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd1 && temp_state[2]==4'd4 && temp_state[3]==4'd3) new_state_val <= 4'd7;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd3 && temp_state[2]==4'd1 && temp_state[3]==4'd4) new_state_val <= 4'd8;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd3 && temp_state[2]==4'd4 && temp_state[3]==4'd1) new_state_val <= 4'd9;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd4 && temp_state[2]==4'd1 && temp_state[3]==4'd3) new_state_val <= 4'd10;
                        else if (temp_state[0]==4'd2 && temp_state[1]==4'd4 && temp_state[2]==4'd3 && temp_state[3]==4'd1) new_state_val <= 4'd11;
                        else if (temp_state[0]==4'd3 && temp_state[1]==4'd1 && temp_state[2]==4'd2 && temp_state[3]==4'd4) new_state_val <= 4'd12;
                        else if (temp_state[0]==4'd3 && temp_state[1]==4'd1 && temp_state[2]==4'd4 && temp_state[3]==4'd2) new_state_val <= 4'd13;
                        else if (temp_state[0]==4'd3 && temp_state[1]==4'd2 && temp_state[2]==4'd1 && temp_state[3]==4'd4) new_state_val <= 4'd14;
                        else new_state_val <= 4'd15;

                        if (!visited[new_state_val]) begin
                            visited[new_state_val] <= 1'b1;
                            queue_state[rear] <= new_state_val;
                            queue_depth[rear] <= queue_depth[front] + 4'd1;
                            rear <= rear + 4'd1;
                            count <= count + 4'd1;
                        end
                        swap_idx <= swap_idx + 3'd1;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = CHECK;
            CHECK: begin
                if (count == 4'd0 || cycle_counter >= MAX_CYCLES)
                    next_state = FINISH;
                else if (queue_state[front] == 4'd0)
                    next_state = FINISH;
                else
                    next_state = GEN;
            end
            GEN: begin
                if (swap_idx < num_swaps)
                    next_state = PROCESS;
                else
                    next_state = CHECK; // All swaps generated for this node
            end
            PROCESS: begin
                if (swap_idx < num_swaps)
                    next_state = GEN; // Loop back to generate next swap
                else begin
                    // Pop from queue
                    next_state = CHECK;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Cycle counter update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 3'd0;
        end else begin
            if (state == IDLE) cycle_counter <= 3'd0;
            else if (state == CHECK) cycle_counter <= cycle_counter + 3'd1;
        end
    end

endmodule