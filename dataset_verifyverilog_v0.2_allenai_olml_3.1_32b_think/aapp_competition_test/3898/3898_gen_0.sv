module puzzle_rearrangement (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [7:0] a_in,
    input wire [7:0] b_in,
    output reg result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] a_reg, b_reg;
    reg [2:0] n_reg;
    reg [2:0] i_counter;
    reg match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 0;
            a_reg <= 0;
            b_reg <= 0;
            i_counter <= 0;
            match <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE && start) begin
                n_reg <= n;
                a_reg <= a_in;
                b_reg <= b_in;
                next_state <= PROCESSING;
            end
        end
    end

    always @(*) begin
        next_state = state;
        match = 1'b1;
        i_counter = 0;

        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
            end
            PROCESSING: begin
                if (i_counter < n_reg) begin
                    if (((a_reg >> i_counter) | (a_reg << (n_reg - i_counter))) == b_reg) begin
                        match = 1'b1;
                        next_state = DONE_STATE;
                    end else begin
                        i_counter = i_counter + 1;
                    end
                end else begin
                    match = 1'b0;
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            result <= match;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule