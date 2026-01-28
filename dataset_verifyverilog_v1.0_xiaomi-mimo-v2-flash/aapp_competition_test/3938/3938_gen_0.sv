module min_cost_white (
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

    // State machine states
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] WAIT_RECT = 2'd1;
    localparam [1:0] COMPUTE   = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [31:0] sum_reg;
    reg [31:0] width_reg;
    reg [31:0] height_reg;
    reg [31:0] cost_reg;
    
    // Intermediate computation signals (combinational)
    wire [31:0] width_calc;
    wire [31:0] height_calc;
    wire [31:0] min_calc;

    // Combinational logic for calculations
    // Width = x2 - x1 + 1 (assuming x2 >= x1)
    assign width_calc = rect_x2 - rect_x1 + 32'd1;
    // Height = y2 - y1 + 1 (assuming y2 >= y1)
    assign height_calc = rect_y2 - rect_y1 + 32'd1;
    // Min cost for rectangle
    assign min_calc = (width_calc < height_calc) ? width_calc : height_calc;

    // State register and synchronous logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sum_reg <= 32'd0;
            width_reg <= 32'd0;
            height_reg <= 32'd0;
            cost_reg <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    sum_reg <= 32'd0;
                    done <= 1'b0;
                end
                
                WAIT_RECT: begin
                    // Wait for valid rectangle data
                    if (rect_valid) begin
                        width_reg <= width_calc;
                        height_reg <= height_calc;
                        cost_reg <= min_calc;
                    end
                end
                
                COMPUTE: begin
                    // Accumulate the cost
                    sum_reg <= sum_reg + cost_reg;
                end
                
                FINISH: begin
                    result <= sum_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = WAIT_RECT;
                else next_state = IDLE;
            end
            
            WAIT_RECT: begin
                if (rect_valid) next_state = COMPUTE;
                else next_state = WAIT_RECT;
            end
            
            COMPUTE: begin
                if (rect_done) next_state = FINISH;
                else next_state = WAIT_RECT;
            end
            
            FINISH: begin
                // Return to idle after done is asserted
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule