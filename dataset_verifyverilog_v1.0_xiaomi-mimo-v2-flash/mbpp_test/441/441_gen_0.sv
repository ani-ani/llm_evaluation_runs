module surface_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] side,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] side_reg;
    reg [15:0] result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational multiplication for side * side
    wire [15:0] side_squared;
    assign side_squared = side_reg * side_reg;  // 8-bit * 8-bit = 16-bit
    
    // FSM State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            side_reg <= 8'd0;
            result_reg <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    result <= 16'd0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        side_reg <= side;
                        cycle_count <= 8'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute: result = 6 * side_reg * side_reg
                    // First compute side^2, then multiply by 6
                    result_reg <= side_squared * 6'd6;
                    
                    // Single cycle computation complete
                    if (cycle_count >= 8'd2) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational next_state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = (cycle_count >= 8'd2) ? FINISH : COMPUTE;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule