module divisor_sum_comparator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] num1,
    input wire [15:0] num2,
    output reg [15:0] sum1,
    output reg [15:0] sum2,
    output reg done,
    output reg equivalent
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_SUM1 = 4'd1;
    localparam [3:0] COMPUTE_SUM2 = 4'd2;
    localparam [3:0] COMPARE = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Computation registers
    reg [15:0] current_num;
    reg [15:0] current_sum;
    reg [15:0] i;
    reg computing_first;
    reg [15:0] quotient;
    
    // Maximum divisor iteration bound (for safety)
    localparam [15:0] MAX_ITER = 16'd256;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE_SUM1;
                else
                    next_state = IDLE;
            end
            
            COMPUTE_SUM1: begin
                // Continue until i*i > current_num or max iterations
                if ((i * i > current_num) || (i >= MAX_ITER))
                    next_state = COMPUTE_SUM2;
                else
                    next_state = COMPUTE_SUM1;
            end
            
            COMPUTE_SUM2: begin
                if ((i * i > current_num) || (i >= MAX_ITER))
                    next_state = COMPARE;
                else
                    next_state = COMPUTE_SUM2;
            end
            
            COMPARE: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum1 <= 16'd0;
            sum2 <= 16'd0;
            done <= 1'b0;
            equivalent <= 1'b0;
            current_num <= 16'd0;
            current_sum <= 16'd0;
            i <= 16'd2;
            computing_first <= 1'b1;
            quotient <= 16'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for num1
                        current_num <= num1;
                        current_sum <= 16'd1;
                        i <= 16'd2;
                        computing_first <= 1'b1;
                    end
                end
                
                COMPUTE_SUM1, COMPUTE_SUM2: begin
                    if (i * i <= current_num && i < MAX_ITER) begin
                        if (current_num % i == 16'd0) begin
                            quotient <= current_num / i;
                            // Check for perfect square
                            if (i * i == current_num) begin
                                current_sum <= current_sum + i;
                            end else begin
                                current_sum <= current_sum + i + (current_num / i);
                            end
                        end
                        i <= i + 16'd1;
                    end
                end
                
                COMPARE: begin
                    if (computing_first) begin
                        // Finished num1, setup for num2
                        sum1 <= current_sum;
                        current_num <= num2;
                        current_sum <= 16'd1;
                        i <= 16'd2;
                        computing_first <= 1'b0;
                    end else begin
                        // Finished num2, do comparison
                        sum2 <= current_sum;
                        equivalent <= (sum1 == current_sum);
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // No action
                end
            endcase
        end
    end

endmodule