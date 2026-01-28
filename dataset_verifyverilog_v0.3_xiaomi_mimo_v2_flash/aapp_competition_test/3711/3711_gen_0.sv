module chocolate_cutting (
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    input [15:0] k,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_POSSIBLE = 3'd1;
    localparam [2:0] COMPUTE_ALPHA  = 3'd2;
    localparam [2:0] COMPUTE_BETA   = 3'd3;
    localparam [2:0] UPDATE_RESULT  = 3'd4;
    localparam [2:0] FINISHED       = 3'd5;
    
    reg [2:0] state, next_state;
    reg [31:0] alpha_reg, beta_reg;
    reg [15:0] temp_n, temp_m, temp_k;
    reg [31:0] division_result;
    reg [31:0] multiplication_result;
    
    // Combinational logic for alpha and beta computation
    always @(*) begin
        division_result = 32'd0;
        multiplication_result = 32'd0;
        
        case (state)
            COMPUTE_ALPHA: begin
                if (temp_k >= temp_n) begin
                    // alpha = m // (k - n + 2)
                    division_result = temp_m / (temp_k - temp_n + 16'd2);
                end else begin
                    // alpha = m * (n // (k + 1))
                    division_result = temp_n / (temp_k + 16'd1);
                    multiplication_result = temp_m * division_result;
                    division_result = multiplication_result;
                end
            end
            
            COMPUTE_BETA: begin
                if (temp_k >= temp_m) begin
                    // beta = n // (k - m + 2)
                    division_result = temp_n / (temp_k - temp_m + 16'd2);
                end else begin
                    // beta = n * (m // (k + 1))
                    division_result = temp_m / (temp_k + 16'd1);
                    multiplication_result = temp_n * division_result;
                    division_result = multiplication_result;
                end
            end
            
            default: begin
                division_result = 32'd0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            alpha_reg <= 32'd0;
            beta_reg <= 32'd0;
            temp_n <= 16'd0;
            temp_m <= 16'd0;
            temp_k <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_n <= n;
                        temp_m <= m;
                        temp_k <= k;
                    end
                end
                
                CHECK_POSSIBLE: begin
                    // Check if k > (n-1) + (m-1)
                    // If impossible, result is -1
                    if (temp_k > (temp_n - 16'd1) + (temp_m - 16'd1)) begin
                        result <= 32'hFFFFFFFF;
                    end
                end
                
                COMPUTE_ALPHA: begin
                    alpha_reg <= division_result;
                end
                
                COMPUTE_BETA: begin
                    beta_reg <= division_result;
                end
                
                UPDATE_RESULT: begin
                    if (alpha_reg > beta_reg) begin
                        result <= alpha_reg;
                    end else begin
                        result <= beta_reg;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // No additional actions
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state; // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_POSSIBLE;
                end
            end
            
            CHECK_POSSIBLE: begin
                next_state = COMPUTE_ALPHA;
            end
            
            COMPUTE_ALPHA: begin
                next_state = COMPUTE_BETA;
            end
            
            COMPUTE_BETA: begin
                next_state = UPDATE_RESULT;
            end
            
            UPDATE_RESULT: begin
                next_state = FINISHED;
            end
            
            FINISHED: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule