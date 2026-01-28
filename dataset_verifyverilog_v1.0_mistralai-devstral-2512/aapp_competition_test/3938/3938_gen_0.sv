module min_cost_white(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] rect_x1,
    input wire [31:0] rect_y1,
    input wire [31:0] rect_x2,
    input wire [31:0] rect_y2,
    input wire rect_valid,
    input wire rect_done,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [31:0] width;
    reg [31:0] height;
    reg [31:0] rect_cost;
    reg [31:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            accumulator <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (rect_valid) begin
                        // Calculate width and height
                        width <= rect_x2 - rect_x1 + 32'd1;
                        height <= rect_y2 - rect_y1 + 32'd1;
                        
                        // Compute min(width, height)
                        if (width < height) begin
                            rect_cost <= width;
                        end else begin
                            rect_cost <= height;
                        end
                        
                        // Add to accumulator
                        accumulator <= accumulator + rect_cost;
                    end
                    
                    // Check if done
                    if (rect_done || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule