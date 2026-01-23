module widget_profit_maximizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_producers,
    input [2:0] num_consumers,
    input [7:0] producer_prices [0:7],
    input [7:0] producer_dates [0:7],
    input [7:0] consumer_prices [0:7],
    input [7:0] consumer_dates [0:7],
    output reg [15:0] max_profit,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CALCULATING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Counters for producers and consumers
    reg [2:0] producer_idx;
    reg [2:0] consumer_idx;

    // Temporary variables for calculations
    reg [7:0] profit_per_day;
    reg [7:0] days;
    reg [15:0] current_profit;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            producer_idx <= 0;
            consumer_idx <= 0;
            max_profit <= 0;
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
                    next_state = CALCULATING;
                    producer_idx = 0;
                    consumer_idx = 0;
                    max_profit = 0;
                    done = 0;
                end
            end
            CALCULATING: begin
                // Calculate profit for current pair
                profit_per_day = consumer_prices[consumer_idx] - producer_prices[producer_idx];
                days = consumer_dates[consumer_idx] - producer_dates[producer_idx];
                current_profit = 0;

                if (profit_per_day > 0 && days > 0) begin
                    current_profit = profit_per_day * days;
                end

                // Update max_profit if current_profit is greater
                if (current_profit > max_profit) begin
                    max_profit = current_profit;
                end

                // Move to next pair
                if (consumer_idx == num_consumers - 1) begin
                    if (producer_idx == num_producers - 1) begin
                        next_state = DONE;
                    end else begin
                        producer_idx = producer_idx + 1;
                        consumer_idx = 0;
                    end
                end else begin
                    consumer_idx = consumer_idx + 1;
                end
            end
            DONE: begin
                done = 1;
                if (start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule