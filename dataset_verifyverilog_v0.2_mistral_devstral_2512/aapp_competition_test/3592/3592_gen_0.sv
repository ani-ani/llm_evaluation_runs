module profit_calculator (
    input clk,
    input rst_n,
    input start,
    input [31:0] total_profit,
    input [31:0] profit_pita,
    input [31:0] profit_pizza,
    output reg [31:0] num_pitas,
    output reg [31:0] num_pizzas,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SEARCH,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] pita_counter;
    reg [31:0] remainder;
    reg [31:0] pizza_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            pita_counter <= 0;
            num_pitas <= 0;
            num_pizzas <= 0;
            valid <= 0;
            done <= 0;
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
                    next_state = SEARCH;
                end
            end
            SEARCH: begin
                if (pita_counter >= (total_profit / profit_pita) + 1) begin
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

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pita_counter <= 0;
            num_pitas <= 0;
            num_pizzas <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    pita_counter <= 0;
                    num_pitas <= 0;
                    num_pizzas <= 0;
                    valid <= 0;
                    done <= 0;
                end
                SEARCH: begin
                    remainder = total_profit - (pita_counter * profit_pita);
                    if (remainder >= 0 && (remainder % profit_pizza) == 0) begin
                        num_pitas <= pita_counter;
                        num_pizzas <= remainder / profit_pizza;
                        valid <= 1;
                    end else begin
                        valid <= 0;
                    end
                    pita_counter <= pita_counter + 1;
                end
                DONE: begin
                    done <= 1;
                    valid <= 0;
                end
            endcase
        end
    end

endmodule