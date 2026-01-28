module semicircle_triangle_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] radius,
    output reg [15:0] area_out,
    output reg done
);

    // State declarations
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] COMPUTE = 1'b1;
    
    reg [0:0] state;
    reg [0:0] next_state;

    // Intermediate signals
    wire [15:0] radius_squared;
    assign radius_squared = radius * radius;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area_out <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            
            COMPUTE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            area_out <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    area_out <= 16'd0;
                    done <= 1'b0;
                end
                
                COMPUTE: begin
                    area_out <= radius_squared >> 1;
                    done <= 1'b1;
                end
                
                default: begin
                    area_out <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule