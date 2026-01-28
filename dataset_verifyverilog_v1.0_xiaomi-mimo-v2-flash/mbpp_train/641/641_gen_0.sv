module nonagonal(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] STATE_IDLE = 3'd0;
    localparam [2:0] STATE_MUL1 = 3'd1;  // Compute 7*n
    localparam [2:0] STATE_MUL2 = 3'd2;  // Compute (7*n - 5) * n
    localparam [2:0] STATE_DIV  = 3'd3;  // Shift right by 1
    localparam [2:0] STATE_DONE = 3'd4;  // Assert done
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [7:0] n_reg;           // Store input n
    reg [15:0] temp_7n;        // Store 7*n (max 7*255=1785, fits in 11 bits)
    reg [31:0] temp_product;   // Store n*(7*n-5) (max 458752, fits in 19 bits)
    
    // Combinational logic for next state and outputs
    always @(*) begin
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_MUL1;
                end else begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_MUL1: begin
                next_state = STATE_MUL2;
            end
            
            STATE_MUL2: begin
                next_state = STATE_DIV;
            end
            
            STATE_DIV: begin
                next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            
            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= STATE_IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
            temp_7n <= 16'd0;
            temp_product <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                    end
                end
                
                STATE_MUL1: begin
                    // Compute 7*n
                    temp_7n <= n_reg * 8'd7;
                end
                
                STATE_MUL2: begin
                    // Compute (7*n - 5) * n
                    // temp_7n is 16-bit, n_reg is 8-bit
                    // Intermediate result fits in 32 bits
                    temp_product <= (temp_7n - 16'd5) * n_reg;
                end
                
                STATE_DIV: begin
                    // Divide by 2 (right shift)
                    // temp_product is 32-bit unsigned
                    result <= temp_product[16:1];  // Shift right by 1
                end
                
                STATE_DONE: begin
                    done <= 1'b1;
                    // result already set in previous cycle
                end
                
                default: begin
                    // Default case handled by state machine logic
                end
            endcase
        end
    end

endmodule