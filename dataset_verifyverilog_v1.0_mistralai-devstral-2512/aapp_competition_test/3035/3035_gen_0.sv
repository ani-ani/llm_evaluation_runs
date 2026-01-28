module LemonadeTrader(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] trade_offer [0:7],
    input wire [2:0] trade_want [0:7],
    input wire [15:0] trade_rate [0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS_TRADE = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [2:0] trade_index;
    reg [15:0] amount [0:7];
    reg [15:0] traded;
    reg [15:0] received;
    reg [15:0] temp_product;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            trade_index <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize amounts
            amount[0] <= 16'd256; // 1.0 liter pink
            amount[1] <= 16'd0;
            amount[2] <= 16'd0;
            amount[3] <= 16'd0;
            amount[4] <= 16'd0;
            amount[5] <= 16'd0;
            amount[6] <= 16'd0;
            amount[7] <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS_TRADE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS_TRADE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (trade_index < 3'd8 && amount[trade_want[trade_index]] > 16'd0) begin
                        // Process trade
                        traded <= amount[trade_want[trade_index]];
                        amount[trade_want[trade_index]] <= 16'd0;
                        // Multiply traded * rate (Q8.8 * Q8.8 = Q16.16)
                        temp_product <= traded * trade_rate[trade_index];
                        // Shift right 8 to get Q8.8
                        received <= temp_product[23:8];
                        // Saturate addition
                        if (amount[trade_offer[trade_index]] + received > 16'd65535) begin
                            amount[trade_offer[trade_index]] <= 16'd65535;
                        end else begin
                            amount[trade_offer[trade_index]] <= amount[trade_offer[trade_index]] + received;
                        end
                        trade_index <= trade_index + 3'd1;
                        next_state <= PROCESS_TRADE;
                    end else if (trade_index < 3'd8) begin
                        // Skip trade if no amount to trade
                        trade_index <= trade_index + 3'd1;
                        next_state <= PROCESS_TRADE;
                    end else begin
                        next_state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Scale blue lemonade (index 1) from Q8.8 to integer liters
                    // Clamp to max 10 liters (10 * 256 = 2560)
                    if (amount[1] > 16'd2560) begin
                        result <= 16'd2560;
                    end else begin
                        result <= amount[1];
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule