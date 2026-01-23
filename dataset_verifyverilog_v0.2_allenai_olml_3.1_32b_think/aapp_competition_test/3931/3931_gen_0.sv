module travel_expense_calculator (input clk, input rst_n, input start, input [7:0] num_trips, input [7:0] max_cards, input [7:0] reg_cost, input [7:0] trans_cost, input [7:0] card_cost, input [7:0] trip_start_char, input [7:0] trip_end_char, input trip_valid, input trip_done, output reg [15:0] result, output reg done, output reg trip_ready);

// Internal registers
reg [2:0] state;
reg [15:0] total_cost;
reg [7:0] last_stop;
reg [3:0] trips_remaining;
reg first_trip;

// Registered inputs
reg [7:0] reg_cost_reg;
reg [7:0] trans_cost_reg;
reg [7:0] card_cost_reg;

// trip_ready is high in IDLE and FINISHED
wire trip_ready_w = (state == 3'd0) || (state == 3'd5);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'd0;
        total_cost <= 16'd0;
        last_stop <= 8'd0;
        trips_remaining <= 4'd0;
        first_trip <= 1'b1;
        reg_cost_reg <= 8'd0;
        trans_cost_reg <= 8'd0;
        card_cost_reg <= 8'd0;
    end else begin
        if (state == 3'd0) begin // IDLE
            if (start) begin
                trips_remaining <= num_trips[3:0];
                reg_cost_reg <= reg_cost;
                trans_cost_reg <= trans_cost;
                card_cost_reg <= card_cost;
                total_cost <= 16'd0;
                last_stop <= 8'd0;
                first_trip <= 1'b1;
                state <= 3'd1;
            end
        end else if (state == 3'd1) begin // RECEIVE_TRIPS
            if (trip_valid) begin
                if (first_trip) begin
                    total_cost <= total_cost + reg_cost_reg;
                    first_trip <= 1'b0;
                end else begin
                    if (trip_start_char == last_stop) begin
                        total_cost <= total_cost + trans_cost_reg;
                    end else begin
                        total_cost <= total_cost + reg_cost_reg;
                    end
                end
                last_stop <= trip_end_char;
                trips_remaining <= trips_remaining - 1;
                if (trips_remaining == 4'd0) begin
                    state <= 3'd2;
                end
            end
        end else if (state == 3'd2) begin // WAIT_FOR_DONE
            if (trip_done) begin
                state <= 3'd3;
            end
        end else if (state == 3'd3) begin // CALCULATE_BENEFIT
            if (total_cost > card_cost_reg) begin
                total_cost <= total_cost - card_cost_reg;
            end
            state <= 3'd5;
        end else if (state == 3'd5) begin // FINISHED
            done <= 1'b1;
            result <= total_cost;
        end
    end
end

assign trip_ready = trip_ready_w;

endmodule