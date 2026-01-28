module peg_board_checker(
    input clk,
    input rst_n,
    input start,
    input [15:0] start_grid,
    input [15:0] target_grid,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BFS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [15:0] current_state;
    reg [15:0] visited [0:8191];
    reg [7:0] queue [0:255];
    reg [7:0] queue_head;
    reg [7:0] queue_tail;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize visited array
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            current_state <= 16'd0;
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            cycle_count <= 10'd0;
            for (i = 0; i < 8192; i = i + 1) begin
                visited[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= BFS;
                        current_state <= start_grid;
                        queue[0] <= start_grid[15:0];
                        queue_head <= 8'd0;
                        queue_tail <= 8'd1;
                        visited[start_grid[15:0]] <= 16'd1;
                    end
                end
                
                BFS: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (current_state == target_grid) begin
                        state <= FINISH;
                        result <= 1'b1;
                    end else if (queue_head == queue_tail || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 1'b0;
                    end else begin
                        current_state <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        // Generate next states
                        generate_next_states;
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

    // Generate next states
    always @(*) begin
        if (state == BFS && queue_head != queue_tail) begin
            reg [15:0] next_state;
            reg [3:0] row, col;
            reg [3:0] new_row, new_col;
            
            for (row = 0; row < 4; row = row + 1) begin
                for (col = 0; col < 4; col = col + 1) begin
                    if (current_state[row*4 + col]) begin
                        // Check up
                        if (row > 1 && current_state[(row-1)*4 + col] && !current_state[(row-2)*4 + col]) begin
                            next_state = current_state;
                            next_state[row*4 + col] = 1'b0;
                            next_state[(row-1)*4 + col] = 1'b0;
                            next_state[(row-2)*4 + col] = 1'b1;
                            if (!visited[next_state] && queue_tail < 256) begin
                                queue[queue_tail] = next_state;
                                queue_tail = queue_tail + 8'd1;
                                visited[next_state] = 1'b1;
                            end
                        end
                        // Check down
                        if (row < 2 && current_state[(row+1)*4 + col] && !current_state[(row+2)*4 + col]) begin
                            next_state = current_state;
                            next_state[row*4 + col] = 1'b0;
                            next_state[(row+1)*4 + col] = 1'b0;
                            next_state[(row+2)*4 + col] = 1'b1;
                            if (!visited[next_state] && queue_tail < 256) begin
                                queue[queue_tail] = next_state;
                                queue_tail = queue_tail + 8'd1;
                                visited[next_state] = 1'b1;
                            end
                        end
                        // Check left
                        if (col > 1 && current_state[row*4 + (col-1)] && !current_state[row*4 + (col-2)]) begin
                            next_state = current_state;
                            next_state[row*4 + col] = 1'b0;
                            next_state[row*4 + (col-1)] = 1'b0;
                            next_state[row*4 + (col-2)] = 1'b1;
                            if (!visited[next_state] && queue_tail < 256) begin
                                queue[queue_tail] = next_state;
                                queue_tail = queue_tail + 8'd1;
                                visited[next_state] = 1'b1;
                            end
                        end
                        // Check right
                        if (col < 2 && current_state[row*4 + (col+1)] && !current_state[row*4 + (col+2)]) begin
                            next_state = current_state;
                            next_state[row*4 + col] = 1'b0;
                            next_state[row*4 + (col+1)] = 1'b0;
                            next_state[row*4 + (col+2)] = 1'b1;
                            if (!visited[next_state] && queue_tail < 256) begin
                                queue[queue_tail] = next_state;
                                queue_tail = queue_tail + 8'd1;
                                visited[next_state] = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule