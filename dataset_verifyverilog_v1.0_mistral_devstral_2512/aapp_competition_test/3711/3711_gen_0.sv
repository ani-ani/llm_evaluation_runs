module chocolate_cutting(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_POSSIBLE = 3'd1;
    localparam [2:0] COMPUTE_ALPHA = 3'd2;
    localparam [2:0] COMPUTE_BETA = 3'd3;
    localparam [2:0] UPDATE_RESULT = 3'd4;
    localparam [2:0] FINISHED = 3'd5;
    
    reg [2:0] state;
    reg [31:0] alpha, beta;
    reg [15:0] temp_n, temp_m;
    reg [15:0] cuts_remaining;
    reg [31:0] division_result;
    reg [31:0] multiplication_result;
    reg [31:0] temp_divisor;
    reg [31:0] temp_dividend;
    
    // Combinational logic for division and multiplication
    always @(*) begin
        case (state)
            COMPUTE_ALPHA: begin
                if (cuts_remaining >= temp_n) begin
                    temp_divisor = cuts_remaining - temp_n + 2;
                    if (temp_divisor != 0) begin
                        division_result = temp_m / temp_divisor;
                    end else begin
                        division_result = 0;
                    end
                end else begin
                    if (cuts_remaining + 1 != 0) begin
                        temp_divisor = cuts_remaining + 1;
                        division_result = temp_m * (temp_n / temp_divisor);
                    end else begin
                        division_result = 0;
                    end
                end
            end
            COMPUTE_BETA: begin
                if (cuts_remaining >= temp_m) begin
                    temp_divisor = cuts_remaining - temp_m + 2;
                    if (temp_divisor != 0) begin
                        division_result = temp_n / temp_divisor;
                    end else begin
                        division_result = 0;
                    end
                end else begin
                    if (cuts_remaining + 1 != 0) begin
                        temp_divisor = cuts_remaining + 1;
                        division_result = temp_n * (temp_m / temp_divisor);
                    end else begin
                        division_result = 0;
                    end
                end
            end
            default: begin
                division_result = 0;
            end
        endcase
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            alpha <= 32'd0;
            beta <= 32'd0;
            temp_n <= 16'd0;
            temp_m <= 16'd0;
            cuts_remaining <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_POSSIBLE;
                        temp_n <= n;
                        temp_m <= m;
                        cuts_remaining <= k;
                    end
                end
                
                CHECK_POSSIBLE: begin
                    if (k > (n - 1) + (m - 1)) begin
                        result <= 32'd4294967295; // -1
                        state <= FINISHED;
                    end else begin
                        state <= COMPUTE_ALPHA;
                    end
                end
                
                COMPUTE_ALPHA: begin
                    alpha <= division_result;
                    state <= COMPUTE_BETA;
                end
                
                COMPUTE_BETA: begin
                    beta <= division_result;
                    state <= UPDATE_RESULT;
                end
                
                UPDATE_RESULT: begin
                    if (alpha > beta) begin
                        result <= alpha;
                    end else begin
                        result <= beta;
                    end
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule