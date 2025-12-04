module palindrome_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] even_count,
    output reg [7:0] odd_count,
    output reg done
);

    typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
    state_t state, next_state;

    reg [7:0] i, next_i;
    reg [7:0] n_reg;
    reg inc_even, inc_odd;

    // Digit extraction
    wire [7:0] hundreds = i / 100;
    wire [7:0] tens = (i % 100) / 10;
    wire [7:0] units = i % 10;

    // Palindrome detection
    wire is_palindrome;
    assign is_palindrome = (i < 10) ? 1'b1 :
                           (i < 100) ? (tens == units) :
                           (hundreds == units);

    wire is_even = (i[0] == 1'b0);

    // State transition logic
    always_comb begin
        next_state = state;
        next_i = i;
        inc_even = 1'b0;
        inc_odd = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_i = 8'd1;
                end
            end
            PROCESSING: begin
                if (i <= n_reg) begin
                    if (is_palindrome) begin
                        if (is_even) inc_even = 1'b1;
                        else inc_odd = 1'b1;
                    end
                    next_i = i + 1;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: next_state = DONE;
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 8'd0;
            odd_count <= 8'd0;
            done <= 1'b0;
            i <= 8'd0;
            n_reg <= 8'd0;
        end else begin
            state <= next_state;
            i <= next_i;
            
            if (state == IDLE && start) begin
                n_reg <= n;
            end
            
            if (state == PROCESSING && i <= n_reg) begin
                if (inc_even) even_count <= even_count + 1;
                if (inc_odd) odd_count <= odd_count + 1;
            end
            
            done <= (next_state == DONE);
        end
    end

endmodule