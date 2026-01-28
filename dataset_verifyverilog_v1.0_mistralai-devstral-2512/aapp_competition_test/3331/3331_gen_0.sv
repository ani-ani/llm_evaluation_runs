module cow_horse_chase(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] L,
    input wire [4:0] A,
    input wire [4:0] B,
    input wire [4:0] P,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] BFS = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Queue parameters
    localparam [6:0] QUEUE_SIZE = 7'd128;
    localparam [6:0] QUEUE_MASK = 7'd127;

    // Queue pointers
    reg [6:0] queue_head;
    reg [6:0] queue_tail;
    reg [6:0] queue_count;

    // Queue storage (15-bit states)
    reg [14:0] queue [0:127];

    // Current state being processed
    reg [14:0] current_state;

    // Next states (4 concurrent)
    reg [14:0] next_states [0:3];

    // Visited/distance BRAM (16x16x16)
    reg [7:0] visited [0:15][0:15][0:15];

    // State extraction
    reg [4:0] cow1_pos;
    reg [4:0] cow2_pos;
    reg [4:0] horse_pos;

    // Move generation
    reg [4:0] new_cow1_pos [0:3];
    reg [4:0] new_cow2_pos [0:3];
    reg [4:0] new_horse_pos [0:3];

    // Capture check
    reg capture_found;

    // Initialize visited memory
    integer i, j, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            queue_head <= 7'd0;
            queue_tail <= 7'd0;
            queue_count <= 7'd0;
            current_state <= 15'd0;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        visited[i][j][k] <= 8'd255;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize queue with start state
                    queue[0] <= {A, B, P};
                    queue_head <= 7'd0;
                    queue_tail <= 7'd1;
                    queue_count <= 7'd1;
                    visited[A][B][P] <= 8'd0;
                    state <= BFS;
                end

                BFS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if queue is empty or max cycles reached
                    if (queue_count == 7'd0 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Dequeue current state
                        current_state <= queue[queue_head];
                        queue_head <= (queue_head + 7'd1) & QUEUE_MASK;
                        queue_count <= queue_count - 7'd1;

                        // Extract positions
                        cow1_pos <= current_state[14:10];
                        cow2_pos <= current_state[9:5];
                        horse_pos <= current_state[4:0];

                        // Generate 4 concurrent next states
                        generate_next_states();

                        // Process each next state
                        for (i = 0; i < 4; i = i + 1) begin
                            if (next_states[i] != 15'd0) begin
                                // Check if this is the capture state
                                if (next_states[i][14:10] == next_states[i][4:0] || 
                                    next_states[i][9:5] == next_states[i][4:0]) begin
                                    capture_found <= 1'b1;
                                    result <= visited[cow1_pos][cow2_pos][horse_pos] + 8'd1;
                                end
                                
                                // Enqueue if not visited
                                if (visited[next_states[i][14:10]][next_states[i][9:5]][next_states[i][4:0]] == 8'd255) begin
                                    visited[next_states[i][14:10]][next_states[i][9:5]][next_states[i][4:0]] <= 
                                        visited[cow1_pos][cow2_pos][horse_pos] + 8'd1;
                                    queue[queue_tail] <= next_states[i];
                                    queue_tail <= (queue_tail + 7'd1) & QUEUE_MASK;
                                    queue_count <= queue_count + 7'd1;
                                end
                            end
                        end

                        // Check if capture was found
                        if (capture_found) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Generate next states function
    function void generate_next_states();
        integer idx;
        reg [4:0] c1, c2, h;
        reg [4:0] new_c1, new_c2, new_h;
        reg [4:0] dist_c1, dist_c2;

        c1 = cow1_pos;
        c2 = cow2_pos;
        h = horse_pos;

        for (idx = 0; idx < 4; idx = idx + 1) begin
            // Generate cow moves (each cow can move -1, 0, or +1)
            case (idx % 3)
                0: new_c1 = c1 + 5'd1;
                1: new_c1 = c1 - 5'd1;
                2: new_c1 = c1;
            endcase

            case ((idx / 3) % 3)
                0: new_c2 = c2 + 5'd1;
                1: new_c2 = c2 - 5'd1;
                2: new_c2 = c2;
            endcase

            // Bound cow positions
            if (new_c1 < 5'd0) new_c1 = 5'd0;
            if (new_c1 > L) new_c1 = L;
            if (new_c2 < 5'd0) new_c2 = 5'd0;
            if (new_c2 > L) new_c2 = L;

            // Calculate distances from horse to cows
            dist_c1 = (new_c1 > h) ? (new_c1 - h) : (h - new_c1);
            dist_c2 = (new_c2 > h) ? (new_c2 - h) : (h - new_c2);

            // Horse moves optimally (toward closest cow)
            if (dist_c1 < dist_c2) begin
                // Move toward cow1
                if (new_c1 > h) begin
                    new_h = h + 5'd2;  // Move +2 toward cow1
                    if (new_h > new_c1) new_h = new_c1;
                end else begin
                    new_h = h - 5'd2;  // Move -2 toward cow1
                    if (new_h < new_c1) new_h = new_c1;
                end
            end else begin
                // Move toward cow2
                if (new_c2 > h) begin
                    new_h = h + 5'd2;  // Move +2 toward cow2
                    if (new_h > new_c2) new_h = new_c2;
                end else begin
                    new_h = h - 5'd2;  // Move -2 toward cow2
                    if (new_h < new_c2) new_h = new_c2;
                end
            end

            // Bound horse position
            if (new_h < 5'd0) new_h = 5'd0;
            if (new_h > L) new_h = L;

            // Check if horse collides with cows (can't move through)
            if (new_h == new_c1 || new_h == new_c2) begin
                // Horse can't move through cows, so don't move
                new_h = h;
            end

            // Store the new state
            next_states[idx] = {new_c1, new_c2, new_h};
        end
    endfunction

endmodule