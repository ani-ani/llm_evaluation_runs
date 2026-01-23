module tuple_modulo (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple1 [0:3],
    input [7:0] tuple2 [0:3],
    output reg [7:0] result [0:3],
    output reg done
);

    // State Encoding
    localparam IDLE    = 3'b000;
    localparam LOAD    = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam STORE   = 3'b011;
    localparam DONE    = 3'b100;

    // Internal Registers
    reg [2:0] current_state, next_state;
    reg [1:0] index; // Iterates 0 to 3
    reg [7:0] current_a;
    reg [7:0] current_b;
    reg [7:0] remainder_reg;
    
    // Logic to handle index increment and termination
    wire last_element;
    assign last_element = (index == 2'd3);

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                // If divisor is 0, skip computation to avoid hanging, treat as 0 result
                if (current_b == 8'b0)
                    next_state = STORE;
                else if (current_a < current_b)
                    next_state = STORE; // Dividend < Divisor, modulo is dividend
                else
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                // Loop until remainder < divisor
                if (remainder_reg < current_b)
                    next_state = STORE;
                else
                    next_state = COMPUTE;
            end
            STORE: begin
                if (last_element)
                    next_state = DONE;
                else
                    next_state = LOAD;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 2'b0;
            done <= 1'b0;
            // Initialize result array
            result[0] <= 8'b0;
            result[1] <= 8'b0;
            result[2] <= 8'b0;
            result[3] <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 2'b0;
                    end
                end

                LOAD: begin
                    // Load current element pair
                    current_a <= tuple1[index];
                    current_b <= tuple2[index];
                    remainder_reg <= tuple1[index]; // Initialize remainder
                end

                COMPUTE: begin
                    // Repeated subtraction: remainder = remainder - divisor
                    if (remainder_reg >= current_b) begin
                        remainder_reg <= remainder_reg - current_b;
                    end
                end

                STORE: begin
                    // Store result (remainder_reg holds the modulo result)
                    result[index] <= remainder_reg;
                    // Increment index for next iteration
                    index <= index + 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
