module triangle_area_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] a,
    input wire signed [15:0] h,
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MULTIPLY = 3'd1;
    localparam [2:0] SHIFT = 3'd2;
    localparam [2:0] DIVIDE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // State and next state registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers for computation
    reg signed [31:0] mult_result_reg;
    reg signed [31:0] result_reg;
    reg signed [63:0] mult_temp;
    reg signed [63:0] div_temp;
    
    // Counter for timing
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            mult_result_reg <= 32'sd0;
            result_reg <= 32'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        mult_temp <= a * h;
                    end
                end
                
                MULTIPLY: begin
                    // Perform multiplication
                    mult_temp <= a * h;
                    mult_result_reg <= mult_temp[47:16];
                    cycle_count <= cycle_count + 4'd1;
                end
                
                SHIFT: begin
                    // Shift right by 16 bits for Q16.16 format
                    mult_result_reg <= mult_temp[47:16];
                    cycle_count <= cycle_count + 4'd1;
                end
                
                DIVIDE: begin
                    // Divide by 2 (right shift by 1)
                    // Arithmetic shift for signed numbers
                    if (mult_result_reg[31]) begin
                        // Negative number - arithmetic shift
                        div_temp <= {32'd0, mult_result_reg} >>> 1;
                    end else begin
                        div_temp <= {32'd0, mult_result_reg} >> 1;
                    end
                    result_reg <= div_temp[31:0];
                    cycle_count <= cycle_count + 4'd1;
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    cycle_count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'sd0;
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = MULTIPLY;
                end else begin
                    next_state = IDLE;
                end
            end
            
            MULTIPLY: begin
                next_state = SHIFT;
            end
            
            SHIFT: begin
                next_state = DIVIDE;
            end
            
            DIVIDE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule