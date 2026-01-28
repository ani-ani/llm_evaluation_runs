module square_perimeter(
    input wire clk,
    input wire rst_n,
    input wire [7:0] side_in,
    input wire start,
    output reg [15:0] perimeter_out,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Combinational multiplication for perimeter calculation
    wire [15:0] perimeter_calc;
    assign perimeter_calc = side_in * 8'd4;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perimeter_out <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Output logic
            case (state)
                CALC: begin
                    perimeter_out <= perimeter_calc;
                    done <= 1'b1;
                end
                DONE_STATE: begin
                    done <= 1'b0;
                end
                default: begin
                    perimeter_out <= perimeter_out;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC;
                else
                    next_state = IDLE;
            end
            CALC: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule