module CenteredHexagonalNumber(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] S1_SUB = 3'd1;
    localparam [2:0] S2_MULT = 3'd2;
    localparam [2:0] S3_FINAL = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Pipeline registers
    reg [7:0] n_reg;
    reg [7:0] n_minus_1;
    reg [15:0] temp;
    reg start_delayed;
    
    // Combinational logic
    wire [15:0] mult_temp;
    wire [15:0] n_plus_1;
    
    // 32-bit intermediate for multiplication (3 * n * (n-1)
    wire [31:0] mult_full;
    
    // Calculate: 3 * n * n_minus_1
    assign mult_full = 32'd3 * n_reg * n_minus_1;
    assign mult_temp = mult_full[15:0]; // Truncate to 16-bit (fits for n <= 255)
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
            n_minus_1 <= 8'd0;
            temp <= 16'd0;
            start_delayed <= 1'b0;
        end else begin
            state <= next_state;
            start_delayed <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_delayed) begin
                        // Capture n on start
                        n_reg <= n;
                        // Special case: if n == 0, n-1 = 0 (though spec says n >= 1)
                        if (n == 8'd0)
                            n_minus_1 <= 8'd0;
                        else
                            n_minus_1 <= n - 8'd1;
                    end
                end
                
                S1_SUB: begin
                    // n_minus_1 already computed in previous cycle
                end
                
                S2_MULT: begin
                    // Compute multiplication
                    temp <= mult_temp;
                end
                
                S3_FINAL: begin
                    // Compute result = temp + 1
                    result <= temp + 16'd1;
                end
                
                DONE_STATE: begin
                    // done already set in next_state logic
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    n_reg <= 8'd0;
                    n_minus_1 <= 8'd0;
                    temp <= 16'd0;
                    start_delayed <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_delayed) begin
                    next_state = S1_SUB;
                end else begin
                    next_state = IDLE;
                end
            end
            
            S1_SUB: begin
                next_state = S2_MULT;
            end
            
            S2_MULT: begin
                next_state = S3_FINAL;
            end
            
            S3_FINAL: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                // After done pulse, return to IDLE
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Done signal output logic
    always @(*) begin
        if (state == DONE_STATE && start_delayed == 1'b0) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule