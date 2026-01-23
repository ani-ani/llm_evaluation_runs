module bandwidth_allocator (
    input clk, rst_n, start,
    input [31:0] a0, a1, a2, a3,
    input [31:0] b0, b1, b2, b3,
    input [31:0] d0, d1, d2, d3,
    input [31:0] t,
    output reg [31:0] x0, x1, x2, x3,
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

reg [3:0] state, next_state;
reg [1:0] index;
reg [31:0] total_d;
reg [31:0] y0, y1, y2, y3;
reg [31:0] x_reg [0:3];
reg [3:0] fixed;
reg [31:0] residual;
reg [31:0] total_y_free;
reg changed;
reg [7:0] cycle_counter;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        x0 <= 32'd0; x1 <= 32'd0; x2 <= 32'd0; x3 <= 32'd0;
        fixed <= 4'b0;
        changed <= 1'b0;
        index <= 2'd0;
        total_d <= 32'd0;
        residual <= 32'd0;
        total_y_free <= 32'd0;
        y0 <= 32'd0; y1 <= 32'd0; y2 <= 32'd0; y3 <= 32'd0;
        x_reg[0] <= 32'd0; x_reg[1] <= 32'd0; x_reg[2] <= 32'd0; x_reg[3] <= 32'd0;
        cycle_counter <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                fixed <= 4'b0;
                changed <= 1'b0;
                index <= 2'd0;
                total_d <= 32'd0;
                cycle_counter <= 8'd0;
            end
            
            COMPUTE_TOTAL_D: begin
                case (index)
                    2'd0: total_d <= total_d + d0;
                    2'd1: total_d <= total_d + d1;
                    2'd2: total_d <= total_d + d2;
                    2'd3: total_d <= total_d + d3;
                endcase
                index <= index + 2'd1;
            end
            
            COMPUTE_Y: begin
                case (index)
                    2'd0: y0 <= (t * d0) / total_d;
                    2'd1: y1 <= (t * d1) / total_d;
                    2'd2: y2 <= (t * d2) / total_d;
                    2'd3: y3 <= (t * d3) / total_d;
                endcase
                index <= index + 2'd1;
            end
            
            INIT_X: begin
                case (index)
                    2'd0: begin
                        if (y0 < a0) begin
                            x_reg[0] <= a0;
                            fixed[0] <= 1'b1;
                        end else if (y0 > b0) begin
                            x_reg[0] <= b0;
                            fixed[0] <= 1'b1;
                        end else begin
                            x_reg[0] <= y0;
                        end
                    end
                    2'd1: begin
                        if (y1 < a1) begin
                            x_reg[1] <= a1;
                            fixed[1] <= 1'b1;
                        end else if (y1 > b1) begin
                            x_reg[1] <= b1;
                            fixed[1] <= 1'b1;
                        end else begin
                            x_reg[1] <= y1;
                        end
                    end
                    2'd2: begin
                        if (y2 < a2) begin
                            x_reg[2] <= a2;
                            fixed[2] <= 1'b1;
                        end else if (y2 > b2) begin
                            x_reg[2] <= b2;
                            fixed[2] <= 1'b1;
                        end else begin
                            x_reg[2] <= y2;
                        end
                    end
                    2'd3: begin
                        if (y3 < a3) begin
                            x_reg[3] <= a3;
                            fixed[3] <= 1'b1;
                        end else if (y3 > b3) begin
                            x_reg[3] <= b3;
                            fixed[3] <= 1'b1;
                        end else begin
                            x_reg[3] <= y3;
                        end
                    end
                endcase
                index <= index + 2'd1;
            end
            
            CHECK_ITERATION: begin
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            COMPUTE_RESIDUAL: begin
                case (index)
                    2'd0: begin
                        if (fixed[0]) residual <= t - x_reg[0];
                        else residual <= t;
                    end
                    2'd1: begin
                        if (fixed[0]) residual <= residual - x_reg[0];
                    end
                    2'd2: begin
                        if (fixed[1]) residual <= residual - x_reg[1];
                    end
                    2'd3: begin
                        if (fixed[2]) residual <= residual - x_reg[2];
                    end
                endcase
                index <= index + 2'd1;
            end
            
            COMPUTE_TOTAL_Y_FREE: begin
                case (index)
                    2'd0: begin
                        if (!fixed[0]) total_y_free <= y0;
                        else total_y_free <= 32'd0;
                    end
                    2'd1: begin
                        if (!fixed[1]) total_y_free <= total_y_free + y1;
                    end
                    2'd2: begin
                        if (!fixed[2]) total_y_free <= total_y_free + y2;
                    end
                    2'd3: begin
                        if (!fixed[3]) total_y_free <= total_y_free + y3;
                    end
                endcase
                index <= index + 2'd1;
            end
            
            UPDATE_X: begin
                case (index)
                    2'd0: begin
                        if (!fixed[0]) begin
                            x_reg[0] <= (residual * y0) / total_y_free;
                            if (x_reg[0] < a0) begin
                                x_reg[0] <= a0;
                                fixed[0] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg[0] > b0) begin
                                x_reg[0] <= b0;
                                fixed[0] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                    end
                    2'd1: begin
                        if (!fixed[1]) begin
                            x_reg[1] <= (residual * y1) / total_y_free;
                            if (x_reg[1] < a1) begin
                                x_reg[1] <= a1;
                                fixed[1] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg[1] > b1) begin
                                x_reg[1] <= b1;
                                fixed[1] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                    end
                    2'd2: begin
                        if (!fixed[2]) begin
                            x_reg[2] <= (residual * y2) / total_y_free;
                            if (x_reg[2] < a2) begin
                                x_reg[2] <= a2;
                                fixed[2] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg[2] > b2) begin
                                x_reg[2] <= b2;
                                fixed[2] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                    end
                    2'd3: begin
                        if (!fixed[3]) begin
                            x_reg[3] <= (residual * y3) / total_y_free;
                            if (x_reg[3] < a3) begin
                                x_reg[3] <= a3;
                                fixed[3] <= 1'b1;
                                changed <= 1'b1;
                            end else if (x_reg[3] > b3) begin
                                x_reg[3] <= b3;
                                fixed[3] <= 1'b1;
                                changed <= 1'b1;
                            end
                        end
                    end
                endcase
                index <= index + 2'd1;
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                x0 <= x_reg[0];
                x1 <= x_reg[1];
                x2 <= x_reg[2];
                x3 <= x_reg[3];
            end
        endcase
    end
end

always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = COMPUTE_TOTAL_D;
            else next_state = IDLE;
        end
        
        COMPUTE_TOTAL_D: begin
            if (index == 2'd3) next_state = COMPUTE_Y;
            else next_state = COMPUTE_TOTAL_D;
        end
        
        COMPUTE_Y: begin
            if (index == 2'd3) next_state = INIT_X;
            else next_state = COMPUTE_Y;
        end
        
        INIT_X: begin
            if (index == 2'd3) next_state = CHECK_ITERATION;
            else next_state = INIT_X;
        end
        
        CHECK_ITERATION: begin
            if (fixed == 4'b1111) next_state = DONE_STATE;
            else if (cycle_counter >= 8'd200) next_state = DONE_STATE;
            else next_state = COMPUTE_RESIDUAL;
        end
        
        COMPUTE_RESIDUAL: begin
            if (index == 2'd3) next_state = COMPUTE_TOTAL_Y_FREE;
            else next_state = COMPUTE_RESIDUAL;
        end
        
        COMPUTE_TOTAL_Y_FREE: begin
            if (index == 2'd3) next_state = UPDATE_X;
            else next_state = COMPUTE_TOTAL_Y_FREE;
        end
        
        UPDATE_X: begin
            if (index == 2'd3) begin
                if (changed) next_state = CHECK_ITERATION;
                else next_state = DONE_STATE;
            end else begin
                next_state = UPDATE_X;
            end
        end
        
        DONE_STATE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule