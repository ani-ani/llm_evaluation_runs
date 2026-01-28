module coke_mixer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [10:0] target_n,
    input wire [2047:0] diff_avail,
    output reg [11:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BFS_INIT = 2'd1;
    localparam [1:0] BFS_RUN = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [10:0] current_state;
    reg [9:0] current_dist;
    reg [10:0] queue_state [0:255];
    reg [9:0] queue_dist [0:255];
    reg [7:0] queue_head;
    reg [7:0] queue_tail;
    reg [2047:0] visited;
    reg [7:0] diff_iter;
    reg [10:0] next_state;
    reg [9:0] next_dist;
    reg diff_found;
    reg [7:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_state <= 11'd0;
            current_dist <= 10'd0;
            for (i = 0; i < 256; i = i + 1) begin
                queue_state[i] <= 11'd0;
                queue_dist[i] <= 10'd0;
            end
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            for (i = 0; i < 2048; i = i + 1) begin
                visited[i] <= 1'b0;
            end
            diff_iter <= 8'd0;
            next_state <= 11'd0;
            next_dist <= 10'd0;
            diff_found <= 1'b0;
            result <= 12'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= BFS_INIT;
                    end
                end

                BFS_INIT: begin
                    // Initialize BFS
                    queue_head <= 8'd0;
                    queue_tail <= 8'd1;
                    queue_state[0] <= 11'd0;
                    queue_dist[0] <= 10'd0;
                    visited[1000] <= 1'b1;  // state 0 is at index 1000
                    state <= BFS_RUN;
                end

                BFS_RUN: begin
                    // Check if queue is empty
                    if (queue_head == queue_tail) begin
                        state <= DONE_STATE;
                    end else begin
                        // Pop from queue
                        current_state <= queue_state[queue_head];
                        current_dist <= queue_dist[queue_head];
                        queue_head <= queue_head + 8'd1;

                        // Check if current state is 0 (solution found)
                        if (current_state == 11'd0 && current_dist != 10'd0) begin
                            result <= current_dist;
                            valid <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            // Iterate through available differences
                            diff_iter <= 8'd0;
                            diff_found <= 1'b0;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for BFS processing
    always @(*) begin
        if (state == BFS_RUN && current_dist != 10'd0) begin
            // Calculate next state and check bounds
            next_state = current_state + (diff_iter - 11'd1000);
            if (next_state >= 11'd0 && next_state <= 11'd2000) begin
                if (diff_avail[diff_iter] && !visited[next_state]) begin
                    next_dist = current_dist + 10'd1;
                    diff_found = 1'b1;
                end else begin
                    diff_found = 1'b0;
                end
            end else begin
                diff_found = 1'b0;
            end
        end else begin
            diff_found = 1'b0;
        end
    end

    // Queue push logic
    always @(posedge clk) begin
        if (state == BFS_RUN && diff_found && queue_tail < 8'd256) begin
            queue_state[queue_tail] <= next_state;
            queue_dist[queue_tail] <= next_dist;
            visited[next_state] <= 1'b1;
            queue_tail <= queue_tail + 8'd1;
        end
    end

    // Diff iteration logic
    always @(posedge clk) begin
        if (state == BFS_RUN && current_dist != 10'd0) begin
            if (diff_iter < 8'd2047) begin
                diff_iter <= diff_iter + 8'd1;
            end else begin
                diff_iter <= 8'd0;
            end
        end
    end

endmodule