module CameraCover #(
    parameter N = 8,
    parameter K = 8
) (
    input clk,
    input rst_n,
    input start,
    input [2:0] a_i [0:7],
    input [2:0] b_i [0:7],
    output reg done,
    output reg [7:0] result
);
    
    localparam [3:0] 
        IDLE = 4'd0,
        LOAD_MASKS = 4'd1,
        INIT_BFS = 4'd2,
        BFS_DEQUEUE = 4'd3,
        BFS_CHECK_COMPLETE = 4'd4,
        PROCESS_CAMERA = 4'd5,
        DONE_STATE = 4'd6;
    
    reg [3:0] state;
    reg [2:0] a_latch[0:7];
    reg [2:0] b_latch[0:7];
    reg [7:0] masks[0:7];
    reg [7:0] current_state;
    reg [3:0] cam_idx;
    reg [7:0] queue[0:255];
    reg [7:0] rd_ptr;
    reg [7:0] wr_ptr;
    reg [255:0] visited;
    reg [3:0] distance[0:255];
    reg [3:0] cam_count;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                a_latch[i] <= 3'd0;
                b_latch[i] <= 3'd0;
                masks[i] <= 8'd0;
            end
            
            current_state <= 8'd0;
            cam_idx <= 4'd0;
            rd_ptr <= 8'd0;
            wr_ptr <= 8'd0;
            visited <= 256'd0;
            
            for (i = 0; i < 256; i = i + 1) begin
                distance[i] <= 4'd0;
            end
            
            for (i = 0; i < 256; i = i + 1) begin
                queue[i] <= 8'd0;
            end
            
            cam_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < K;
                        i = i + 1) begin
                            a_latch[i] <= a_i[i];
                            b_latch[i] <= b_i[i];
                        end
                        cam_count <= 4'd0;
                        state <= LOAD_MASKS;
                    end
                end
                
                LOAD_MASKS: begin
                    if (cam_count < K) begin
                        if (a_latch[cam_count] == 3'd0) begin
                            masks[cam_count] <= 8'd0;
                        end else if (a_latch[cam_count] <= b_latch[cam_count]) begin
                            masks[cam_count] <= ((8'd1 << (b_latch[cam_count] - a_latch[cam_count] + 3'd1)) - 3'd1) << (a_latch[cam_count] - 3'd1);
                        end else begin
                            masks[cam_count] <= (((8'd1 << (N - a_latch[cam_count] + 1)) - 1) << (a_latch[cam_count] - 1)) | ((8'd1 << b_latch[cam_count]) - 1);
                        end
                        cam_count <= cam_count + 1;
                    end else begin
                        state <= INIT_BFS;
                    end
                end
                
                INIT_BFS: begin
                    visited <= 256'd0;
                    visited[0] <= 1'b1;
                    distance[0] <= 4'd0;
                    queue[0] <= 8'd0;
                    rd_ptr <= 8'd0;
                    wr_ptr <= 8'd1;
                    state <= BFS_DEQUEUE;
                end
                
                BFS_DEQUEUE: begin
                    if (rd_ptr == wr_ptr) begin
                        result <= 8'd0;
                        state <= DONE_STATE;
                    end else begin
                        current_state <= queue[rd_ptr];
                        rd_ptr <= rd_ptr + 8'd1;
                        state <= BFS_CHECK_COMPLETE;
                    end
                end
                
                BFS_CHECK_COMPLETE: begin
                    if (current_state == 8'd255) begin
                        result <= {4'd0, distance[current_state]};
                        state <= DONE_STATE;
                    end else begin
                        cam_idx <= 4'd0;
                        state <= PROCESS_CAMERA;
                    end
                end
                
                PROCESS_CAMERA: begin
                    begin
                        reg [7:0] next_state_candidate;
                        next_state_candidate = current_state | masks[cam_idx];
                        if (next_state_candidate != current_state) begin
                            if (visited[next_state_candidate] == 1'b0) begin
                                visited[next_state_candidate] <= 1'b1;
                                distance[next_state_candidate] <= distance[current_state] + 4'd1;
                                queue[wr_ptr] <= next_state_candidate;
                                wr_ptr <= wr_ptr + 8'd1;
                            end
                        end
                        
                        if (cam_idx == K - 1) begin
                            state <= BFS_DEQUEUE;
                        end else begin
                            cam_idx <= cam_idx + 4'd1;
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
endmodule