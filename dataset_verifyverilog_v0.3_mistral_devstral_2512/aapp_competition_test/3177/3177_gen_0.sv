module sort_minimum_swaps(
    input clk, rst_n, start,
    input [7:0] initial_perm,  // 4 numbers, 2 bits each (0-3 mapped from 1-4)
    input [23:0] swaps,        // 6 possible swaps, 4 bits each (positions 0-3)
    input [2:0] num_swaps,     // number of valid swaps (1-6)
    output reg [4:0] min_swaps,
    output reg done,
    output reg error
);

// Internal parameters
localparam [2:0] STATE_IDLE = 3'd0;
localparam [2:0] STATE_INIT = 3'd1;
localparam [2:0] STATE_DEQUEUE = 3'd2;
localparam [2:0] STATE_CHECK = 3'd3;
localparam [2:0] STATE_PROCESS_SWAP = 3'd4;
localparam [2:0] STATE_NEXT_SWAP = 3'd5;
localparam [2:0] STATE_DONE = 3'd6;
localparam [2:0] STATE_ERROR = 3'd7;

// Registers and wires
reg [2:0] current_state, next_state;
reg [7:0] target_perm;  // 00_01_10_11 = [1,2,3,4]
reg [4:0] distance_reg;  // stores current distance
reg [7:0] current_perm;  // current state from queue
reg [2:0] swap_counter;  // which swap we're processing
reg [7:0] new_perm;      // perm after swap
reg [255:0] visited;     // 256-bit visited array
reg [7:0] queue [0:23];  // FIFO for states (max 24 states)
reg [4:0] dist_queue [0:23]; // distance for each state
reg [4:0] head, tail;    // FIFO pointers
reg [4:0] min_swaps_reg;
reg done_reg, error_reg;

// FIFO status
wire fifo_empty = (head == tail);
wire fifo_full = (head == tail + 5'd24);  // should never happen for N=4

// Swap extraction (each swap is 4 bits: [3:2]=pos1, [1:0]=pos2, 0-indexed)
wire [1:0] swap_pos1 = swaps[swap_counter*4 +: 2];
wire [1:0] swap_pos2 = swaps[swap_counter*4 + 2 +: 2];

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= STATE_IDLE;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        STATE_IDLE: begin
            if (start) next_state = STATE_INIT;
        end
        STATE_INIT: begin
            next_state = STATE_DEQUEUE;
        end
        STATE_DEQUEUE: begin
            if (fifo_empty) next_state = STATE_ERROR;
            else next_state = STATE_CHECK;
        end
        STATE_CHECK: begin
            if (current_perm == target_perm) next_state = STATE_DONE;
            else next_state = STATE_PROCESS_SWAP;
        end
        STATE_PROCESS_SWAP: begin
            if (swap_counter >= num_swaps) next_state = STATE_DEQUEUE;
            else if (visited[new_perm]) next_state = STATE_NEXT_SWAP;
            else next_state = STATE_NEXT_SWAP;  // enqueue in same cycle
        end
        STATE_NEXT_SWAP: begin
            if (swap_counter < num_swaps) next_state = STATE_PROCESS_SWAP;
            else next_state = STATE_DEQUEUE;
        end
        STATE_DONE, STATE_ERROR: begin
            next_state = STATE_IDLE;
        end
        default: next_state = STATE_IDLE;
    endcase
end

// Output logic and datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        min_swaps <= 5'd0;
        done <= 1'b0;
        error <= 1'b0;
        distance_reg <= 5'd0;
        swap_counter <= 3'd0;
        head <= 5'd0;
        tail <= 5'd0;
        visited <= 256'd0;
        target_perm <= 8'b00_01_10_11;  // [1,2,3,4]
    end else begin
        done <= 1'b0;
        error <= 1'b0;
        
        case (current_state)
            STATE_INIT: begin
                // Initialize visited array and queue
                visited <= 256'd0;
                head <= 5'd0;
                tail <= 5'd0;
                distance_reg <= 5'd0;
                swap_counter <= 3'd0;
                // Enqueue initial state
                queue[0] <= initial_perm;
                dist_queue[0] <= 5'd0;
                tail <= 5'd1;
                visited[initial_perm] <= 1'b1;
            end
            
            STATE_DEQUEUE: begin
                if (!fifo_empty) begin
                    current_perm <= queue[head];
                    distance_reg <= dist_queue[head];
                    head <= head + 5'd1;
                    swap_counter <= 3'd0;
                end
            end
            
            STATE_PROCESS_SWAP: begin
                if (swap_counter < num_swaps) begin
                    // Calculate new permutation after swap
                    new_perm <= perform_swap(current_perm, swap_pos1, swap_pos2);
                end
            end
            
            STATE_NEXT_SWAP: begin
                if (swap_counter < num_swaps && !visited[new_perm]) begin
                    // Enqueue new state
                    if (tail < 5'd24) begin
                        queue[tail] <= new_perm;
                        dist_queue[tail] <= distance_reg + 5'd1;
                        tail <= tail + 5'd1;
                        visited[new_perm] <= 1'b1;
                    end
                end
                swap_counter <= swap_counter + 3'd1;
            end
            
            STATE_DONE: begin
                min_swaps <= distance_reg;
                done <= 1'b1;
            end
            
            STATE_ERROR: begin
                error <= 1'b1;
            end
        endcase
    end
end

// Helper function to perform swap (must be combinational)
function [7:0] perform_swap;
    input [7:0] perm;
    input [1:0] pos1;
    input [1:0] pos2;
    reg [1:0] val1, val2;
    begin
        // Extract values at positions
        val1 = perm[pos1*2 +: 2];
        val2 = perm[pos2*2 +: 2];
        // Swap and reconstruct
        perform_swap = perm;
        perform_swap[pos1*2 +: 2] = val2;
        perform_swap[pos2*2 +: 2] = val1;
    end
endfunction

endmodule