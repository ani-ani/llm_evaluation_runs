module puzzle_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] grid_initial,
    output reg [3:0] result,
    output reg done
);

reg [2:0] state;
reg [5:0] front, rear;
reg [31:0] current_grid;
reg [3:0] current_depth;
reg [31:0] goal = 32'h0055aaff;
reg [35:0] queue [0:63];
reg [31:0] visited [0:1023];
reg [9:0] visit_idx;
reg [10:0] reset_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        front <= 0;
        rear <= 0;
        current_grid <= 0;
        current_depth <= 0;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            3'd0: begin
                if (start) begin
                    state <= 1;
                    current_grid <= grid_initial;
                    current_depth <= 0;
                    front <= front + 1;
                    rear <= rear + 1;
                    queue[rear-1] <= {grid_initial, current_depth};
                end
            end
            1: begin
                if (front > rear) begin
                    state <= 2;
                end
            end
            2: begin
                if (front < rear) begin
                    current_grid <= queue[front][31:0];
                    current_depth <= queue[front][3:0];
                    front <= front + 1;
                    if (current_grid == goal) begin
                        result <= current_depth;
                        done <= 1;
                        state <= 3;
                    end else begin
                        if (rear < 64) begin
                            rear <= rear + 1;
                            queue[rear-1] <= {32'b0, current_depth +1};
                        end
                    end
                end
            end
            3: begin
            end
        endcase
    end
end

endmodule