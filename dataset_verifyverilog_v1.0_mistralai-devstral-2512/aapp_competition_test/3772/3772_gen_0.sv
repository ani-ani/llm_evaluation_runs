module ResistorCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a_in,
    input wire [63:0] b_in,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [63:0] a_reg, b_reg;
    reg [63:0] sum_reg;
    reg [7:0] iteration_count;
    localparam [7:0] MAX_ITERATIONS = 8'd128;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            sum_reg <= 64'd0;
            iteration_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATING;
                end
            end
            CALCULATING: begin
                if (b_reg == 64'd0 || iteration_count >= MAX_ITERATIONS) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 64'd0;
            b_reg <= 64'd0;
            sum_reg <= 64'd0;
            iteration_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        a_reg <= a_in;
                        b_reg <= b_in;
                        sum_reg <= 64'd0;
                        iteration_count <= 8'd0;
                    end
                end
                CALCULATING: begin
                    if (b_reg != 64'd0 && iteration_count < MAX_ITERATIONS) begin
                        // Compute quotient and remainder
                        reg [63:0] quotient;
                        reg [63:0] remainder;
                        reg [63:0] temp_a;
                        reg [63:0] temp_b;
                        
                        // Sequential division algorithm
                        temp_a = a_reg;
                        temp_b = b_reg;
                        quotient = 64'd0;
                        remainder = 64'd0;
                        
                        // Simple division by repeated subtraction
                        // (For synthesis, this will be optimized)
                        if (temp_b != 64'd0) begin
                            quotient = temp_a / temp_b;
                            remainder = temp_a % temp_b;
                        end
                        
                        // Update sum and registers
                        sum_reg <= sum_reg + quotient;
                        a_reg <= temp_b;
                        b_reg <= remainder;
                        iteration_count <= iteration_count + 8'd1;
                    end
                end
                DONE_STATE: begin
                    result <= sum_reg;
                    done <= 1'b1;
                end
                default: begin
                    a_reg <= 64'd0;
                    b_reg <= 64'd0;
                    sum_reg <= 64'd0;
                    iteration_count <= 8'd0;
                end
            endcase
        end
    end

    // Clear done signal after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state != DONE_STATE) begin
                done <= 1'b0;
            end
        end
    end

endmodule