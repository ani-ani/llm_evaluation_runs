module land_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [3:0] rect_x1,
    input wire [3:0] rect_y1,
    input wire [3:0] rect_x2,
    input wire [3:0] rect_y2,
    input wire rect_valid,
    output reg [15:0] area,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_RECT = 3'd1;
    localparam [2:0] UPDATE_GRID = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [1:0] rect_count;
    reg [3:0] rect_x1_reg, rect_y1_reg, rect_x2_reg, rect_y2_reg;
    reg [3:0] x, y;
    reg [8:0] area_acc;
    reg [15:0] grid [0:15];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rect_count <= 2'd0;
            area <= 16'd0;
            done <= 1'b0;
            area_acc <= 9'd0;
            x <= 4'd0;
            y <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                grid[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            grid[i] <= 16'd0;
                        end
                        rect_count <= 2'd0;
                        state <= WAIT_RECT;
                    end
                end

                WAIT_RECT: begin
                    if (rect_valid) begin
                        rect_x1_reg <= rect_x1;
                        rect_y1_reg <= rect_y1;
                        rect_x2_reg <= rect_x2;
                        rect_y2_reg <= rect_y2;
                        x <= 4'd0;
                        y <= 4'd0;
                        state <= UPDATE_GRID;
                    end
                end

                UPDATE_GRID: begin
                    if (x >= rect_x1_reg && x < rect_x2_reg && y >= rect_y1_reg && y < rect_y2_reg) begin
                        grid[x][y] <= 1'b1;
                    end

                    if (y == 4'd15) begin
                        y <= 4'd0;
                        if (x == 4'd15) begin
                            rect_count <= rect_count + 1'd1;
                            if (rect_count + 1'd1 == n) begin
                                state <= COMPUTE;
                                x <= 4'd0;
                                y <= 4'd0;
                                area_acc <= 9'd0;
                            end else begin
                                state <= WAIT_RECT;
                            end
                        end else begin
                            x <= x + 1'd1;
                        end
                    end else begin
                        y <= y + 1'd1;
                    end
                end

                COMPUTE: begin
                    if (grid[x][y]) begin
                        area_acc <= area_acc + 1'd1;
                    end

                    if (y == 4'd15) begin
                        y <= 4'd0;
                        if (x == 4'd15) begin
                            area <= {7'd0, area_acc};
                            state <= DONE_STATE;
                        end else begin
                            x <= x + 1'd1;
                        end
                    end else begin
                        y <= y + 1'd1;
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