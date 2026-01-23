module max_non_square (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input signed [31:0] data_in,
    input [9:0] count_in,
    output reg signed [31:0] max_out,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t state, next_state;
    reg [9:0] count_reg;
    reg [31:0] sqrt_val;
    reg [31:0] guess;
    reg [5:0] iter;
    reg [31:0] abs_data;
    reg is_square;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_out <= 32'h80000000; // -Infinity
            done <= 0;
            count_reg <= 0;
            sqrt_val <= 0;
            guess <= 0;
            iter <= 0;
            abs_data <= 0;
            is_square <= 0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        max_out <= 32'h80000000;
                        done <= 0;
                        count_reg <= count_in;
                        next_state <= PROCESSING;
                    end
                end
                PROCESSING: begin
                    if (valid_in) begin
                        // Check if data_in is a perfect square
                        if (data_in[31]) begin // Negative
                            is_square <= 0;
                        end else begin // Non-negative
                            abs_data <= data_in;
                            // Initialize guess for sqrt
                            guess <= (abs_data + 1) >> 1;
                            iter <= 0;
                            // Start binary search
                            next_state <= PROCESSING;
                        end
                    end
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Binary search for sqrt
    always @(posedge clk) begin
        if (state == PROCESSING && valid_in && !data_in[31]) begin
            if (iter < 16) begin
                if (guess * guess > abs_data) begin
                    guess <= guess - ((guess - (abs_data / guess)) >> 1);
                end else begin
                    guess <= guess + ((abs_data / guess) - guess) >> 1;
                end
                iter <= iter + 1;
            end else begin
                // Check if guess^2 == abs_data
                if (guess * guess == abs_data) begin
                    is_square <= 1;
                end else begin
                    is_square <= 0;
                end
                // Update max if not square
                if (!is_square && data_in > max_out) begin
                    max_out <= data_in;
                end
                // Decrement count
                count_reg <= count_reg - 1;
                if (count_reg == 0) begin
                    next_state <= DONE;
                end
            end
        end
    end

    // Default next state
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: next_state = IDLE;
            PROCESSING: begin
                if (count_reg == 0) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            DONE: next_state = IDLE;
        endcase
    end

endmodule