module FogCoverageCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire fog_valid,
    input wire [7:0] fog_day,
    input wire [3:0] fog_x1,
    input wire [3:0] fog_x2,
    input wire [3:0] fog_y1,
    input wire [3:0] fog_y2,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Net coverage grid (16x16)
    reg [255:0] net_grid;
    
    // Internal signals
    reg [3:0] x;
    reg [3:0] y;
    reg [7:0] x_index;
    reg [7:0] y_index;
    reg rectangle_covered;
    reg rectangle_processed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            net_grid <= 256'd0;
            x <= 4'd0;
            y <= 4'd0;
            x_index <= 8'd0;
            y_index <= 8'd0;
            rectangle_covered <= 1'b1;
            rectangle_processed <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        net_grid <= 256'd0;
                        result <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we have valid fog data
                    if (fog_valid && !rectangle_processed) begin
                        // Reset coverage check
                        rectangle_covered <= 1'b1;
                        x <= fog_x1;
                        y <= fog_y1;
                        x_index <= 8'd0;
                        y_index <= 8'd0;
                        rectangle_processed <= 1'b0;
                    end
                    
                    // Check rectangle coverage
                    if (!rectangle_processed) begin
                        // Calculate current position
                        x_index <= {y[3:0], x[3:0]};
                        
                        // Check if current cell is covered
                        if (!net_grid[x_index]) begin
                            rectangle_covered <= 1'b0;
                        end
                        
                        // Move to next cell
                        if (x == fog_x2) begin
                            if (y == fog_y2) begin
                                rectangle_processed <= 1'b1;
                                
                                // If not fully covered, increment result and update grid
                                if (!rectangle_covered) begin
                                    result <= result + 8'd1;
                                    
                                    // Update net grid
                                    x <= fog_x1;
                                    y <= fog_y1;
                                end
                            end else begin
                                x <= fog_x1;
                                y <= y + 4'd1;
                            end
                        end else begin
                            x <= x + 4'd1;
                        end
                    end else if (rectangle_processed && !rectangle_covered) begin
                        // Update net grid
                        x_index <= {y[3:0], x[3:0]};
                        net_grid[x_index] <= 1'b1;
                        
                        // Move to next cell
                        if (x == fog_x2) begin
                            if (y == fog_y2) begin
                                rectangle_processed <= 1'b0;
                            end else begin
                                x <= fog_x1;
                                y <= y + 4'd1;
                            end
                        end else begin
                            x <= x + 4'd1;
                        end
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES || (fog_valid && rectangle_processed && rectangle_covered)) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule