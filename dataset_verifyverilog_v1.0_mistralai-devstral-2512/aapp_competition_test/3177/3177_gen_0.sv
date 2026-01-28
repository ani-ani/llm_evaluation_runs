module min_swaps(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] perm [0:3],
    input wire [1:0] swap_a [0:5],
    input wire [1:0] swap_b [0:5],
    input wire [2:0] num_swaps,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] INIT_BFS  = 4'd1;
    localparam [3:0] PROCESS   = 4'd2;
    localparam [3:0] FINISH    = 4'd3;

    // BFS state encoding: 16-bit (4 elements * 4 bits each)
    reg [15:0] current_state;
    reg [15:0] next_state;
    reg [15:0] queue [0:7];  // Queue for BFS (max depth 8)
    reg [2:0] queue_head;
    reg [2:0] queue_tail;
    reg [2:0] queue_size;
    reg [3:0] current_depth;
    reg [3:0] min_swaps_found;
    reg [3:0] state;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd7;

    // Helper functions
    function [15:0] swap_elements;
        input [15:0] state_in;
        input [1:0] a;
        input [1:0] b;
        reg [15:0] state_out;
        integer i;
        begin
            for (i = 0; i < 4; i = i + 1) begin
                if (i == a) begin
                    state_out[15:12] = state_in[11:8];
                end else if (i == b) begin
                    state_out[11:8] = state_in[15:12];
                end else begin
                    state_out[(15 - (i * 4)):(12 - (i * 4))] = state_in[(15 - (i * 4)):(12 - (i * 4))];
                end
            end
            swap_elements = state_out;
        end
    endfunction

    function [3:0] is_sorted;
        input [15:0] state_in;
        begin
            if ((state_in[15:12] == 4'd1) &&
                (state_in[11:8] == 4'd2) &&
                (state_in[7:4] == 4'd3) &&
                (state_in[3:0] == 4'd4)) begin
                is_sorted = 4'd1;
            end else begin
                is_sorted = 4'd0;
            end
        end
    endfunction

    function [3:0] state_in_queue;
        input [15:0] state_in;
        integer i;
        begin
            state_in_queue = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (queue[i] == state_in) begin
                    state_in_queue = 4'd1;
                end
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_state <= 16'd0;
            next_state <= 16'd0;
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            queue_size <= 3'd0;
            current_depth <= 4'd0;
            min_swaps_found <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= INIT_BFS;
                    end
                end

                INIT_BFS: begin
                    // Initialize BFS with input permutation
                    current_state[15:12] = perm[0];
                    current_state[11:8] = perm[1];
                    current_state[7:4] = perm[2];
                    current_state[3:0] = perm[3];
                    queue[0] = current_state;
                    queue_head <= 3'd0;
                    queue_tail <= 3'd1;
                    queue_size <= 3'd1;
                    current_depth <= 4'd0;
                    min_swaps_found <= 4'd0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Check if current state is sorted
                    if (is_sorted(current_state)) begin
                        min_swaps_found = current_depth;
                        state <= FINISH;
                    end else if (cycle_count >= MAX_CYCLES || queue_size == 3'd0) begin
                        // Timeout or queue empty
                        state <= FINISH;
                    end else begin
                        // Process next state from queue
                        current_state = queue[queue_head];
                        queue_head = (queue_head + 3'd1) % 3'd8;
                        queue_size = queue_size - 3'd1;
                        
                        // Generate next states by applying allowed swaps
                        integer i;
                        for (i = 0; i < num_swaps; i = i + 1) begin
                            next_state = swap_elements(current_state, swap_a[i], swap_b[i]);
                            if (!state_in_queue(next_state) && queue_size < 3'd8) begin
                                queue[queue_tail] = next_state;
                                queue_tail = (queue_tail + 3'd1) % 3'd8;
                                queue_size = queue_size + 3'd1;
                            end
                        end
                        current_depth = current_depth + 4'd1;
                    end
                end

                FINISH: begin
                    result <= min_swaps_found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule