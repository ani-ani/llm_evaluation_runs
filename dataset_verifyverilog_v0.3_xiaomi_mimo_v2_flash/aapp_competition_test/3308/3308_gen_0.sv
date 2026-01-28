module kernel_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire signed [31:0] x [0:7],
    input wire signed [31:0] y [0:7],
    output reg [63:0] area,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] idx;
    reg signed [63:0] sum_reg;
    reg signed [63:0] x_mult;
    reg signed [63:0] y_mult;
    reg signed [63:0] cross_term;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 64'd0;
            done <= 1'b0;
            idx <= 3'd0;
            sum_reg <= 64'd0;
            x_mult <= 64'd0;
            y_mult <= 64'd0;
            cross_term <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 3'd0;
                    sum_reg <= 64'd0;
                    if (start && n >= 3'd3) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate cross product term: x[idx] * y[idx+1] - x[idx+1] * y[idx]
                    if (idx < n - 1) begin
                        x_mult <= $signed(x[idx]) * $signed(y[idx + 1]);
                        y_mult <= $signed(x[idx + 1]) * $signed(y[idx]);
                    end else begin
                        // Last vertex connects to first: x[n-1] * y[0] - x[0] * y[n-1]
                        x_mult <= $signed(x[idx]) * $signed(y[0]);
                        y_mult <= $signed(x[0]) * $signed(y[idx]);
                    end
                    
                    // Add to running sum
                    cross_term <= x_mult - y_mult;
                    sum_reg <= sum_reg + cross_term;
                    
                    if (idx < n - 1) begin
                        idx <= idx + 3'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Compute absolute value and divide by 2
                    if (sum_reg < 64'd0) begin
                        area <= (-sum_reg) >> 1;
                    end else begin
                        area <= sum_reg >> 1;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule