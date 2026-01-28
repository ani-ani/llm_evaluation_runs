module NonagonalNumberCalc (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] MULT1 = 3'd1;
    localparam [2:0] SUB = 3'd2;
    localparam [2:0] MULT2 = 3'd3;
    localparam [2:0] DIV2 = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] n_reg;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
            temp_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        n_reg <= n_in;
                    end
                end
                
                MULT1: begin
                    // Calculate 7 * n
                    temp_result <= n_reg * 8'd7;
                end
                
                SUB: begin
                    // Calculate (7 * n) - 5
                    temp_result <= temp_result - 16'd5;
                end
                
                MULT2: begin
                    // Calculate n * (7 * n - 5)
                    temp_result <= n_reg * temp_result;
                end
                
                DIV2: begin
                    // Divide by 2 (right shift)
                    result <= temp_result >> 1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = MULT1;
                end else begin
                    next_state = IDLE;
                end
            end
            
            MULT1: begin
                next_state = SUB;
            end
            
            SUB: begin
                next_state = MULT2;
            end
            
            MULT2: begin
                next_state = DIV2;
            end
            
            DIV2: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule