module rectangle_area_calc (
    input clk,
    input rst_n,
    input start,
    input [7:0] length,
    input [7:0] width,
    output reg [15:0] area,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Combinational multiplication for area calculation
    wire [15:0] area_calc;
    assign area_calc = length * width;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Output updates based on state
            case (next_state)
                IDLE: begin
                    area <= area;
                    done <= 1'b0;
                end
                CALC: begin
                    area <= area_calc;
                    done <= 1'b0;
                end
                DONE_STATE: begin
                    area <= area;  // Hold result
                    done <= 1'b1;
                end
                default: begin
                    area <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC;
                end else begin
                    next_state = IDLE;
                end
            end
            CALC: begin
                // Calculation takes 1 cycle
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                // Done pulse for 1 cycle, then back to idle
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule