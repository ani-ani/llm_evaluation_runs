module m_perfect_checker(
    input clk,
    input rst_n,
    input start,
    input signed [63:0] x_in,
    input signed [63:0] y_in,
    input signed [63:0] m_in,
    output reg [31:0] result,
    output reg done
);
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] NEGATIVE = 3'd2;
    localparam [2:0] SIMULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg signed [63:0] x, y, m;
    reg [31:0] op_count;
    reg [7:0] cycle_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            x <= 64'd0;
            y <= 64'd0;
            m <= 64'd0;
            op_count <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    op_count <= 32'd0;
                    if (start) begin
                        x <= x_in;
                        y <= y_in;
                        m <= m_in;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd200) begin
                        result <= -32'd1;
                        state <= DONE_STATE;
                    end else if (x >= m || y >= m) begin
                        result <= 32'd0;
                        state <= DONE_STATE;
                    end else if (x <= 64'd0 && y <= 64'd0) begin
                        result <= -32'd1;
                        state <= DONE_STATE;
                    end else if (x <= 64'd0 || y <= 64'd0) begin
                        state <= NEGATIVE;
                    end else begin
                        state <= SIMULATE;
                    end
                end
                
                NEGATIVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd200) begin
                        result <= -32'd1;
                        state <= DONE_STATE;
                    end else if (x <= 64'd0) begin
                        x <= x + y;
                        op_count <= op_count + 32'd1;
                        state <= CHECK;
                    end else if (y <= 64'd0) begin
                        y <= x + y;
                        op_count <= op_count + 32'd1;
                        state <= CHECK;
                    end else begin
                        state <= CHECK;
                    end
                end
                
                SIMULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd200) begin
                        result <= -32'd1;
                        state <= DONE_STATE;
                    end else if (x >= m || y >= m) begin
                        result <= op_count;
                        state <= DONE_STATE;
                    end else begin
                        if (x <= y) begin
                            x <= x + y;
                        end else begin
                            y <= x + y;
                        end
                        op_count <= op_count + 32'd1;
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