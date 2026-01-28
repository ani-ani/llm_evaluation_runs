module FruitCounter(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:31],
    input [7:0] total,
    output reg [7:0] mango,
    output reg done
);
    
    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SCAN_X    = 4'd1;
    localparam [3:0] SCAN_AND  = 4'd2;
    localparam [3:0] SCAN_Y    = 4'd3;
    localparam [3:0] COMPUTE   = 4'd4;
    localparam [3:0] FINISH    = 4'd5;
    
    reg [3:0] state, next_state;
    reg [7:0] apples, oranges;
    reg [7:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            apples <= 8'd0;
            oranges <= 8'd0;
            index <= 8'd0;
            mango <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SCAN_X;
                        index <= 8'd0;
                        apples <= 8'd0;
                        oranges <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SCAN_X: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < 8'd32) begin
                        if (str[index] >= 8'd48 && str[index] <= 8'd57) begin
                            apples <= (apples * 8'd10) + (str[index] - 8'd48);
                        end else if (apples > 8'd0 && str[index] == 8'd32) begin
                            next_state <= SCAN_AND;
                        end
                        index <= index + 8'd1;
                    end else begin
                        next_state <= SCAN_AND;
                    end
                end
                
                SCAN_AND: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < 8'd32) begin
                        if (str[index] == 8'd97 && str[index+1] == 8'd110 && str[index+2] == 8'd100) begin
                            next_state <= SCAN_Y;
                            index <= index + 8'd3;
                        end else begin
                            index <= index + 8'd1;
                        end
                    end else begin
                        next_state <= SCAN_Y;
                    end
                end
                
                SCAN_Y: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < 8'd32) begin
                        if (str[index] >= 8'd48 && str[index] <= 8'd57) begin
                            oranges <= (oranges * 8'd10) + (str[index] - 8'd48);
                        end else if (oranges > 8'd0 && str[index] == 8'd32) begin
                            next_state <= COMPUTE;
                        end
                        index <= index + 8'd1;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (apples > 8'd255) apples <= 8'd255;
                    if (oranges > 8'd255) oranges <= 8'd255;
                    
                    mango <= total - apples - oranges;
                    if (mango > 8'd255) mango <= 8'd255;
                    else if (mango < 8'd0) mango <= 8'd0;
                    
                    next_state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule