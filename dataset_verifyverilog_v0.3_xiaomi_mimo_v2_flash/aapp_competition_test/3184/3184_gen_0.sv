module CameraCover #(
    parameter N = 8,
    parameter K = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] a_i [0:K-1],
    input wire [2:0] b_i [0:K-1],
    output reg done,
    output reg [7:0] result
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_MASKS = 3'd1;
    localparam [2:0] INIT_BFS = 3'd2;
    localparam [2:0] BFS_DEQUEUE = 3'd3;
    localparam [2:0] BFS_PROCESS = 3'd4;
    localparam [2:0] UPDATE_QUEUE = 3'd5;
    localparam [2:0] DONE = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] i_counter;          // Counter for iterating through cameras/states
    reg [7:0] cycle_count;        // Safety timeout
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Mask storage: K masks, each N bits
    reg [N-1:0] masks [0:K-1];
    
    // BFS state storage
    reg visited [0:(1<<N)-1];     // 256 entries for N=8
    reg [3:0] distance [0:(1<<N)-1]; // Max distance is K (<=8), 4 bits sufficient
    
    // Queue implementation (circular buffer)
    reg [N-1:0] queue [0:(1<<N)-1]; // State values
    reg [7:0] q_head;
    reg [7:0] q_tail;
    reg [7:0] q_count;
    
    // Temporary registers for BFS processing
    reg [N-1:0] current_state;
    reg [N-1:0] next_state_val;
    reg [N-1:0] target_state;
    
    // Helper wires for mask computation
    reg [N-1:0] mask_temp;
    reg [2:0] a_val, b_val;
    
    integer idx;

    // Mask Computation Logic (combinational helper)
    always @(*) begin
        mask_temp = {N{1'b0}};
        a_val = a_i[i_counter[2:0]];
        b_val = b_i[i_counter[2:0]];
        
        if (a_val != 3'd0) begin
            if (a_val <= b_val) begin
                // Non-wrap: set bits from a_val-1 to b_val-1
                // (b_val - a_val + 1) bits
                mask_temp = ((1 << (b_val - a_val + 1)) - 1) << (a_val - 1);
            end else begin
                // Wrap around: a_val-1 to N-1 and 0 to b_val-1
                // First part: bits a_val-1 to N-1
                mask_temp = ((1 << (N - a_val + 1)) - 1) << (a_val - 1);
                // Second part: bits 0 to b_val-1
                mask_temp = mask_temp | ((1 << b_val) - 1);
            end
        end
        // If a_val == 0, mask stays 0
    end

    // Target state calculation
    always @(*) begin
        next_state_val = current_state | masks[i_counter[2:0]];
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            i_counter <= 8'd0;
            cycle_count <= 8'd0;
            q_head <= 8'd0;
            q_tail <= 8'd0;
            q_count <= 8'd0;
            current_state <= {N{1'b0}};
            target_state <= {N{1'b0}};
            
            // Initialize memory arrays
            for (idx = 0; idx < (1<<N); idx = idx + 1) begin
                visited[idx] <= 1'b0;
                distance[idx] <= 4'd0;
                queue[idx] <= {N{1'b0}};
            end
            for (idx = 0; idx < K; idx = idx + 1) begin
                masks[idx] <= {N{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD_MASKS;
                        i_counter <= 8'd0;
                    end
                end

                LOAD_MASKS: begin
                    // Compute mask for current camera
                    masks[i_counter[2:0]] <= mask_temp;
                    i_counter <= i_counter + 8'd1;
                    if (i_counter == K - 1) begin
                        state <= INIT_BFS;
                    end
                end

                INIT_BFS: begin
                    // Initialize BFS arrays
                    if (i_counter < (1<<N)) begin
                        visited[i_counter] <= 1'b0;
                        distance[i_counter] <= 4'd0;
                        queue[i_counter] <= {N{1'b0}};
                        i_counter <= i_counter + 8'd1;
                    end else begin
                        // Set up initial state
                        visited[0] <= 1'b1;
                        distance[0] <= 4'd0;
                        queue[0] <= {N{1'b0}};
                        q_head <= 8'd0;
                        q_tail <= 8'd1;
                        q_count <= 8'd1;
                        i_counter <= 8'd0;
                        state <= BFS_DEQUEUE;
                        target_state <= {(1<<N)-1};
                    end
                end

                BFS_DEQUEUE: begin
                    if (q_count == 8'd0) begin
                        // Queue empty - impossible
                        state <= DONE;
                        result <= 8'd0;
                    end else begin
                        current_state <= queue[q_head[7:0]];
                        q_head <= q_head + 8'd1;
                        q_count <= q_count - 8'd1;
                        i_counter <= 8'd0;
                        state <= BFS_PROCESS;
                    end
                end

                BFS_PROCESS: begin
                    // Check if all walls covered
                    if (current_state == target_state) begin
                        state <= DONE;
                        result <= {4'd0, distance[current_state]};
                    end else begin
                        // Check next camera
                        if (i_counter < K) begin
                            next_state_val <= current_state | masks[i_counter[2:0]];
                            state <= UPDATE_QUEUE;
                        end else begin
                            // All cameras processed for this state
                            state <= BFS_DEQUEUE;
                        end
                    end
                end

                UPDATE_QUEUE: begin
                    if (next_state_val != current_state && !visited[next_state_val]) begin
                        visited[next_state_val] <= 1'b1;
                        distance[next_state_val] <= distance[current_state] + 1'b1;
                        queue[q_tail[7:0]] <= next_state_val;
                        q_tail <= q_tail + 8'd1;
                        q_count <= q_count + 8'd1;
                    end
                    i_counter <= i_counter + 8'd1;
                    state <= BFS_PROCESS;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Safety timeout
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= DONE;
                result <= 8'd0;
            end
        end
    end

endmodule