module first_digit_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] number_in,
    output reg [3:0] first_digit,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [15:0] current_value;
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd10;

    // Division by 10 using bit shifts and subtraction
    wire [15:0] divided_by_2;
    wire [15:0] divided_by_5;
    wire [15:0] quotient;
    wire [15:0] remainder;

    assign divided_by_2 = current_value >> 1;
    assign divided_by_5 = divided_by_2 >> 1 + divided_by_2 >> 2 + divided_by_2 >> 4 + divided_by_2 >> 8 + divided_by_2 >> 16;

    assign quotient = divided_by_5;
    assign remainder = current_value - quotient * 10;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end

            LOAD: begin
                if (current_value >= 16'd10)
                    next_state = DIVIDE;
                else
                    next_state = FINISH;
            end

            DIVIDE: begin
                if (iteration_count < MAX_ITERATIONS && current_value >= 16'd10)
                    next_state = DIVIDE;
                else
                    next_state = FINISH;
            end

            FINISH: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 16'd0;
            iteration_count <= 4'd0;
            first_digit <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_count <= 4'd0;
                end

                LOAD: begin
                    current_value <= number_in;
                    iteration_count <= 4'd0;
                end

                DIVIDE: begin
                    current_value <= quotient;
                    iteration_count <= iteration_count + 4'd1;
                end

                FINISH: begin
                    first_digit <= current_value[3:0];
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule