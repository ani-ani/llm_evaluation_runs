module rounded_avg(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] m,
    output reg [7:0] result,
    output reg error,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_RANGE = 3'b001;
    localparam CALC_SUM = 3'b010;
    localparam CALC_COUNT = 3'b011;
    localparam DIVIDE = 3'b100;
    localparam ROUND = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [8:0] sum;
    reg [7:0] count;
    reg [7:0] avg_quotient;
    reg [7:0] remainder;
    reg calc_done;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'b0;
            error <= 1'b0;
            done <= 1'b0;
            sum <= 9'b0;
            count <= 8'b0;
            avg_quotient <= 8'b0;
            remainder <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        // Initialize for new computation
                        sum <= 9'b0;
                        count <= 8'b0;
                        avg_quotient <= 8'b0;
                        remainder <= 8'b0;
                    end
                end

                CHECK_RANGE: begin
                    if (n > m) begin
                        error <= 1'b1;
                    end else begin
                        error <= 1'b0;
                    end
                end

                CALC_SUM: begin
                    sum <= {1'b0, n} + {1'b0, m}; // 9-bit sum
                end

                CALC_COUNT: begin
                    count <= m - n + 1;
                end

                DIVIDE: begin
                    // Integer division: sum / count
                    if (count != 0) begin
                        avg_quotient <= sum / count;
                        remainder <= sum % count;
                    end else begin
                        avg_quotient <= 8'b0;
                        remainder <= 8'b0;
                    end
                end

                ROUND: begin
                    // Round to nearest integer
                    // If remainder >= (count + 1) / 2, round up
                    if (remainder >= ((count + 1) >> 1)) begin
                        result <= avg_quotient + 1;
                    end else begin
                        result <= avg_quotient;
                    end
                end

                DONE: begin
                    if (!error) begin
                        // Result already computed in ROUND state
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state combination logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_RANGE;
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK_RANGE: begin
                if (n > m) begin
                    next_state = DONE;
                end else begin
                    next_state = CALC_SUM;
                end
            end

            CALC_SUM: begin
                next_state = CALC_COUNT;
            end

            CALC_COUNT: begin
                next_state = DIVIDE;
            end

            DIVIDE: begin
                next_state = ROUND;
            end

            ROUND: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule