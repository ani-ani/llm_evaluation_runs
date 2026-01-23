module ticket_optimizer #(
    parameter N = 8 
)(
    input clk,
    input rst_n, // active low
    input start,
    input [2:0] trip_zone,
    input [7:0] trip_time,
    input load_trip,
    input compute,
    output reg [15:0] min_cost,
    output reg done,
    output reg [2:0] debug_state 
);

// Internal signals
reg [2:0] state;
reg [7:0] trip_counter;
reg [15:0] min_cost_reg;
reg done_reg;
reg [2:0] debug_reg;

// State definitions
localparam STATE_IDLE = 3'b000;
localparam STATE_LOADING = 3'b001;
localparam STATE_DONE = 3'b100;

// Default values
always @(posedge clk) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        trip_counter <= 8'b0;
        min_cost_reg <= 16'b0;
        done_reg <= 1'b0;
        debug_reg <= 3'b000;
    end else begin
        state <= state; // Default hold
        trip_counter <= trip_counter;
        min_cost_reg <= min_cost_reg;
        done_reg <= done_reg;
        debug_reg <= debug_reg;
        // State transitions and logic here
        if (state == STATE_IDLE) begin
            if (start) begin
                state <= STATE_LOADING;
            end
        end else if (state == STATE_LOADING) begin
            if (load_trip) begin
                trip_counter <= trip_counter + 1;
                if (trip_counter == N) begin
                    state <= STATE_DONE;
                    done_reg <= 1'b1;
                end
            end
        end
    end
end

// Assign outputs
assign min_cost = min_cost_reg;
assign done = done_reg;
assign debug_state = state;

endmodule