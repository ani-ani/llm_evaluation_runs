module card_score_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] a_in,
    input [3:0] b_in,
    output reg [15:0] max_score,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t current_state, next_state;
    reg [3:0] a_reg, b_reg;
    reg [15:0] score_reg;
    reg [3:0] counter;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            max_score <= 16'b0;
            a_reg <= 4'b0;
            b_reg <= 4'b0;
            score_reg <= 16'b0;
            counter <= 4'b0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    a_reg = a_in;
                    b_reg = b_in;
                    score_reg = 16'b0;
                    counter = 4'b0;
                end
            end
            PROCESSING: begin
                if (counter == 10) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Processing logic
    always @(posedge clk) begin
        if (current_state == PROCESSING) begin
            counter <= counter + 1;
            if (counter == 1) begin
                // Calculate optimal score
                // Group all 'o's into one block: A^2
                // Distribute 'x's into (A + 1) blocks if possible
                if (b_reg == 0) begin
                    score_reg = $signed({1'b0, a_reg * a_reg});
                end else if (a_reg == 0) begin
                    score_reg = -$signed({1'b0, b_reg * b_reg});
                end else begin
                    // Calculate optimal x distribution
                    reg [3:0] num_x_blocks = a_reg + 1;
                    reg [3:0] x_per_block = b_reg / num_x_blocks;
                    reg [3:0] remainder = b_reg % num_x_blocks;
                    reg [15:0] x_score = 0;
                    
                    // Calculate x score
                    if (remainder == 0) begin
                        x_score = $signed({1'b0, x_per_block * x_per_block}) * num_x_blocks;
                    end else begin
                        x_score = $signed({1'b0, x_per_block * x_per_block}) * (num_x_blocks - 1) + 
                                 $signed({1'b0, (x_per_block + 1) * (x_per_block + 1)});
                    end
                    
                    // Calculate total score
                    score_reg = $signed({1'b0, a_reg * a_reg}) - x_score;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (current_state == DONE) begin
            max_score <= score_reg;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule