module ice_cream_transfer(
    input clk,
    input rst_n,
    input start,
    input [7:0] vol_0,
    input [7:0] vol_1,
    input [7:0] vol_2,
    input [7:0] vol_3,
    input [7:0] target_t,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam NUM_BOTTLES = 4;
    localparam MAX_VOLUME = 16;
    localparam TARGET_T = 256;
    localparam MAX_STATES = 256;
    localparam STATE_WIDTH = 12; // 4 bits mask + 8 bits amount
    localparam QUEUE_WIDTH = 8; // 8-bit queue index
    localparam PARENT_WIDTH = 16; // 16-bit parent pointer

    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BFS_INIT = 2'd1;
    localparam [1:0] BFS_RUN = 2'd2;
    localparam [1:0] CHECK_TARGET = 2'd3;
    localparam [1:0] DONE_STATE = 2'd4;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // BFS queue and visited
    reg [STATE_WIDTH-1:0] queue [0:MAX_STATES-1];
    reg [QUEUE_WIDTH-1:0] queue_head, queue_tail;
    reg [STATE_WIDTH-1:0] current_state;
    reg [STATE_WIDTH-1:0] visited [0:MAX_STATES-1];
    reg [PARENT_WIDTH-1:0] parent [0:MAX_STATES-1];

    // State encoding: [11:8] = mask, [7:0] = amount
    reg [3:0] current_mask;
    reg [7:0] current_amount;

    // Bottle volumes
    reg [7:0] volumes [0:NUM_BOTTLES-1];

    // Target found flag
    reg target_found;

    // Initialize volumes on reset or start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            target_found <= 1'b0;
            
            // Initialize volumes
            volumes[0] <= vol_0;
            volumes[1] <= vol_1;
            volumes[2] <= vol_2;
            volumes[3] <= vol_3;
            
            // Clear visited and parent arrays
            integer i;
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                visited[i] <= {4'd0, 8'd0};
                parent[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= BFS_INIT;
                    end
                end
                
                BFS_INIT: begin
                    // Initialize queue with starting state (all empty, amount=0)
                    queue[0] <= {4'd0, 8'd0};
                    queue_head <= 8'd0;
                    queue_tail <= 8'd1;
                    visited[0] <= {4'd0, 8'd0};
                    parent[0] <= 16'd0;
                    state <= BFS_RUN;
                end
                
                BFS_RUN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if queue is empty
                    if (queue_head == queue_tail || cycle_count >= MAX_CYCLES) begin
                        state <= CHECK_TARGET;
                    end else begin
                        // Dequeue current state
                        current_state <= queue[queue_head];
                        current_mask <= current_state[11:8];
                        current_amount <= current_state[7:0];
                        
                        // Check if current state is target
                        if (current_amount == target_t) begin
                            target_found <= 1'b1;
                            state <= CHECK_TARGET;
                        end else begin
                            // Generate next states
                            integer i, j;
                            reg [STATE_WIDTH-1:0] next_state;
                            reg [QUEUE_WIDTH-1:0] next_tail;
                            
                            // Fill empty bottles
                            for (i = 0; i < NUM_BOTTLES; i = i + 1) begin
                                if (~current_mask[i]) begin
                                    next_state = {current_mask | (1 << i), current_amount + volumes[i]};
                                    
                                    // Check if visited
                                    reg visited_flag = 1'b0;
                                    for (j = 0; j < MAX_STATES; j = j + 1) begin
                                        if (visited[j] == next_state) begin
                                            visited_flag = 1'b1;
                                        end
                                    end
                                    
                                    if (!visited_flag && queue_tail < MAX_STATES) begin
                                        next_tail = queue_tail + 8'd1;
                                        queue[queue_tail] <= next_state;
                                        visited[queue_tail] <= next_state;
                                        parent[queue_tail] <= queue_head;
                                        queue_tail <= next_tail;
                                    end
                                end
                            end
                            
                            // Empty full bottles
                            for (i = 0; i < NUM_BOTTLES; i = i + 1) begin
                                if (current_mask[i]) begin
                                    next_state = {current_mask & ~(1 << i), current_amount - volumes[i]};
                                    
                                    // Check if visited
                                    reg visited_flag = 1'b0;
                                    for (j = 0; j < MAX_STATES; j = j + 1) begin
                                        if (visited[j] == next_state) begin
                                            visited_flag = 1'b1;
                                        end
                                    end
                                    
                                    if (!visited_flag && queue_tail < MAX_STATES) begin
                                        next_tail = queue_tail + 8'd1;
                                        queue[queue_tail] <= next_state;
                                        visited[queue_tail] <= next_state;
                                        parent[queue_tail] <= queue_head;
                                        queue_tail <= next_tail;
                                    end
                                end
                            end
                            
                            // Transfer between bottles
                            for (i = 0; i < NUM_BOTTLES; i = i + 1) begin
                                for (j = 0; j < NUM_BOTTLES; j = j + 1) begin
                                    if (i != j && current_mask[i] && ~current_mask[j]) begin
                                        next_state = {current_mask & ~(1 << i) | (1 << j), current_amount};
                                        
                                        // Check if visited
                                        reg visited_flag = 1'b0;
                                        for (j = 0; j < MAX_STATES; j = j + 1) begin
                                            if (visited[j] == next_state) begin
                                                visited_flag = 1'b1;
                                            end
                                        end
                                        
                                        if (!visited_flag && queue_tail < MAX_STATES) begin
                                            next_tail = queue_tail + 8'd1;
                                            queue[queue_tail] <= next_state;
                                            visited[queue_tail] <= next_state;
                                            parent[queue_tail] <= queue_head;
                                            queue_tail <= next_tail;
                                        end
                                    end
                                end
                            end
                            
                            // Move to next state
                            queue_head <= queue_head + 8'd1;
                        end
                    end
                end
                
                CHECK_TARGET: begin
                    if (target_found) begin
                        result <= 8'd1;
                    end else begin
                        result <= 8'd0;
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule