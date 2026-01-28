module bandwidth_allocator(
    input clk,
    input rst_n,
    input start,
    input [31:0] a0,
    input [31:0] a1,
    input [31:0] a2,
    input [31:0] a3,
    input [31:0] b0,
    input [31:0] b1,
    input [31:0] b2,
    input [31:0] b3,
    input [31:0] d0,
    input [31:0] d1,
    input [31:0] d2,
    input [31:0] d3,
    input [31:0] t,
    output reg [31:0] x0,
    output reg [31:0] x1,
    output reg [31:0] x2,
    output reg [31:0] x3,
    output reg done
);

    // State encoding
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_TOTAL_D = 4'd1;
    localparam [3:0] COMPUTE_Y = 4'd2;
    localparam [3:0] INIT_X = 4'd3;
    localparam [3:0] CHECK_ITERATION = 4'd4;
    localparam [3:0] COMPUTE_RESIDUAL = 4'd5;
    localparam [3:0] COMPUTE_TOTAL_Y_FREE = 4'd6;
    localparam [3:0] UPDATE_X = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state;
    reg [1:0] index;
    reg [31:0] total_d;
    reg [31:0] y0, y1, y2, y3;
    reg [31:0] x_reg0, x_reg1, x_reg2, x_reg3;
    reg [3:0] fixed;
    reg [31:0] residual;
    reg [31:0] total_y_free;
    reg changed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            fixed <= 4'd0;
            changed <= 1'b0;
            index <= 2'd0;
            total_d <= 32'd0;
            residual <= 32'd0;
            total_y_free <= 32'd0;
            x_reg0 <= 32'd0;
            x_reg1 <= 32'd0;
            x_reg2 <= 32'd0;
            x_reg3 <= 32'd0;
            x0 <= 32'd0;
            x1 <= 32'd0;
            x2 <= 32'd0;
            x3 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_TOTAL_D;
                        index <= 2'd0;
                        total_d <= 32'd0;
                    end
                end

                COMPUTE_TOTAL_D: begin
                    case (index)
                        2'd0: total_d <= total_d + d0;
                        2'd1: total_d <= total_d + d1;
                        2'd2: total_d <= total_d + d2;
                        2'd3: total_d <= total_d + d3;
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        state <= COMPUTE_Y;
                        index <= 2'd0;
                    end
                end

                COMPUTE_Y: begin
                    case (index)
                        2'd0: y0 <= (t * d0) / total_d;
                        2'd1: y1 <= (t * d1) / total_d;
                        2'd2: y2 <= (t * d2) / total_d;
                        2'd3: y3 <= (t * d3) / total_d;
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        state <= INIT_X;
                        index <= 2'd0;
                    end
                end

                INIT_X: begin
                    case (index)
                        2'd0: begin
                            x_reg0 <= y0;
                            if (y0 < a0) begin
                                x_reg0 <= a0;
                                fixed[0] <= 1'b1;
                            end else if (y0 > b0) begin
                                x_reg0 <= b0;
                                fixed[0] <= 1'b1;
                            end
                        end
                        2'd1: begin
                            x_reg1 <= y1;
                            if (y1 < a1) begin
                                x_reg1 <= a1;
                                fixed[1] <= 1'b1;
                            end else if (y1 > b1) begin
                                x_reg1 <= b1;
                                fixed[1] <= 1'b1;
                            end
                        end
                        2'd2: begin
                            x_reg2 <= y2;
                            if (y2 < a2) begin
                                x_reg2 <= a2;
                                fixed[2] <= 1'b1;
                            end else if (y2 > b2) begin
                                x_reg2 <= b2;
                                fixed[2] <= 1'b1;
                            end
                        end
                        2'd3: begin
                            x_reg3 <= y3;
                            if (y3 < a3) begin
                                x_reg3 <= a3;
                                fixed[3] <= 1'b1;
                            end else if (y3 > b3) begin
                                x_reg3 <= b3;
                                fixed[3] <= 1'b1;
                            end
                        end
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        state <= CHECK_ITERATION;
                        index <= 2'd0;
                        changed <= 1'b0;
                    end
                end

                CHECK_ITERATION: begin
                    if (fixed == 4'b1111) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPUTE_RESIDUAL;
                        index <= 2'd0;
                        residual <= t;
                    end
                end

                COMPUTE_RESIDUAL: begin
                    case (index)
                        2'd0: if (fixed[0]) residual <= residual - x_reg0;
                        2'd1: if (fixed[1]) residual <= residual - x_reg1;
                        2'd2: if (fixed[2]) residual <= residual - x_reg2;
                        2'd3: if (fixed[3]) residual <= residual - x_reg3;
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        state <= COMPUTE_TOTAL_Y_FREE;
                        index <= 2'd0;
                        total_y_free <= 32'd0;
                    end
                end

                COMPUTE_TOTAL_Y_FREE: begin
                    case (index)
                        2'd0: if (!fixed[0]) total_y_free <= total_y_free + y0;
                        2'd1: if (!fixed[1]) total_y_free <= total_y_free + y1;
                        2'd2: if (!fixed[2]) total_y_free <= total_y_free + y2;
                        2'd3: if (!fixed[3]) total_y_free <= total_y_free + y3;
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        state <= UPDATE_X;
                        index <= 2'd0;
                    end
                end

                UPDATE_X: begin
                    case (index)
                        2'd0: if (!fixed[0]) begin
                            x_reg0 <= (residual * y0) / total_y_free;
                            if (x_reg0 < a0) begin
                                x_reg0 <= a0;
                                fixed[0] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg0 > b0) begin
                                x_reg0 <= b0;
                                fixed[0] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                        2'd1: if (!fixed[1]) begin
                            x_reg1 <= (residual * y1) / total_y_free;
                            if (x_reg1 < a1) begin
                                x_reg1 <= a1;
                                fixed[1] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg1 > b1) begin
                                x_reg1 <= b1;
                                fixed[1] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                        2'd2: if (!fixed[2]) begin
                            x_reg2 <= (residual * y2) / total_y_free;
                            if (x_reg2 < a2) begin
                                x_reg2 <= a2;
                                fixed[2] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg2 > b2) begin
                                x_reg2 <= b2;
                                fixed[2] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                        2'd3: if (!fixed[3]) begin
                            x_reg3 <= (residual * y3) / total_y_free;
                            if (x_reg3 < a3) begin
                                x_reg3 <= a3;
                                fixed[3] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg3 > b3) begin
                                x_reg3 <= b3;
                                fixed[3] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                    endcase
                    index <= index + 2'd1;
                    if (index == 2'd3) begin
                        if (changed) begin
                            state <= COMPUTE_RESIDUAL;
                            index <= 2'd0;
                            residual <= t;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    x0 <= x_reg0;
                    x1 <= x_reg1;
                    x2 <= x_reg2;
                    x3 <= x_reg3;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule