module game_solver (
    input clk,
    input rst_n, // active low
    input [1:0] start_pos,
    input [1:0] target_pos,
    input start,
    output reg [7:0] result,
    output reg done
);

reg [1:0] state_reg;
reg [5:0] iter_counter;
reg [7:0] dist [3][3];
reg [7:0] next_dist [3][3];

parameter IDLE = 2'b00;
parameter COMPUTE = 2'b01;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        iter_counter <= 0;
        dist[0][0] <= 8'b0; dist[0][1] <=8'b255; dist[0][2] <=8'b255;
        dist[1][0] <=8'b255; dist[1][1] <=8'b0; dist[1][2] <=8'b255;
        dist[2][0] <=8'b255; dist[2][1] <=8'b255; dist[2][2] <=8'b0;
    end else begin
        if (state_reg == IDLE) begin
            if (start) begin
                state_reg <= COMPUTE;
                iter_counter <= 0;
                done <= 0;
            end
        end else if (state_reg == COMPUTE) begin
            if (iter_counter < 32) begin
                next_dist[0][0] <= 8'b0;
                next_dist[0][1] <= 8'1 + dist[1][1];
                next_dist[0][2] <= 8'1 + dist[1][2];
                if (dist[1][0] < dist[0][0]) begin
                    next_dist[1][0] <= 8'1 + dist[1][0];
                end else begin
                    next_dist[1][0] <= 8'1 + dist[0][0];
                end
                next_dist[1][1] <= 8'b0;
                if (dist[1][2] < dist[0][2]) begin
                    next_dist[1][2] <= 8'1 + dist[1][2];
                end else begin
                    next_dist[1][2] <= 8'1 + dist[0][2];
                end
                if (dist[0][0] > dist[1][0]) begin
                    if (dist[0][0] > dist[2][0]) begin
                        next_dist[2][0] <= 8'1 + dist[0][0];
                    end else begin
                        if (dist[0][0] < dist[2][0]) begin
                            next_dist[2][0] <= 8'1 + dist[0][0];
                        end else begin
                            next_dist[2][0] <= 8'1 + dist[2][0];
                        end
                    end
                end else begin
                    if (dist[0][0] > dist[2][0]) begin
                        if (dist[1][0] < dist[0][0]) begin
                            next_dist[2][0] <= 8'1 + dist[1][0];
                        end else begin
                            next_dist[2][0] <= 8'1 + dist[0][0];
                        end
                    end else begin
                        if (dist[1][0] < dist[2][0]) begin
                            next_dist[2][0] <= 8'1 + dist[1][0];
                        end else begin
                            next_dist[2][0] <= 8'1 + dist[2][0];
                        end
                    end
                end
                if (dist[0][1] > dist[1][1]) begin
                    if (dist[0][1] > dist[2][1]) begin
                        next_dist[2][1] <= 8'1 + dist[0][1];
                    end else begin
                        if (dist[0][1] < dist[2][1]) begin
                            next_dist[2][1] <= 8'1 + dist[0][1];
                        end else begin
                            next_dist[2][1] <= 8'1 + dist[2][1];
                        end
                    end
                end else begin
                    if (dist[0][1] > dist[2][1]) begin
                        if (dist[1][1] < dist[0][1]) begin
                            next_dist[2][1] <= 8'1 + dist[1][1];
                        end else begin
                            next_dist[2][1] <= 8'1 + dist[0][1];
                        end
                    end else begin
                        if (dist[1][1] < dist[2][1]) begin
                            next_dist[2][1] <= 8'1 + dist[1][1];
                        end else begin
                            next_dist[2][1] <= 8'1 + dist[2][1];
                        end
                    end
                end
                next_dist[2][2] <= 8'b0;
                dist <= next_dist;
                iter_counter <= iter_counter + 1;
            end else begin
                state_reg <= IDLE;
                done <= 1;
            end
        end
    end
end

assign result = dist[start_pos][target_pos];

endmodule