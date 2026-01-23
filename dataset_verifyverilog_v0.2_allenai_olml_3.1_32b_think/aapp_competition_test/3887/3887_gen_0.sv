module rebus_solver (
    input clk,
    input rst_n,
    input start,
    input [199:0] char_in,
    input [7:0] n_in,
    output result_valid,
    output is_possible,
    output [10:0][7:0] sol_vals,
    output [10:0] sol_signs,
    output [3:0] num_terms
);

// Parameters
localparam MAX_TERMS = 11;

// State machine
reg [1:0] state;
reg [7:0] idle_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        idle_counter <= 8'd0;
    end else begin
        if (state == 2'b00) begin // IDLE
            if (start) begin
                if (idle_counter == 0) begin
                    idle_counter <= 2; // count down 2 cycles
                end
                if (idle_counter > 0) begin
                    idle_counter <= idle_counter - 1;
                end
                if (idle_counter == 0) begin
                    state <= 2'b01; // PARSE
                end
            end
        end
    end
end

// 30-cycle timer
reg [5:0] timer;
always @(posedge clk) begin
    if (!rst_n) begin
        timer <= 6'd0;
    end else if (state == 2'b01) // PARSE state, start timer?
    begin
        if (timer == 0) begin
            timer <= 30;
        end
        if (timer > 0) begin
            timer <= timer - 1;
        end
        if (timer == 0) begin
            result_valid <= 1'b1;
            state <= 2'b11; // OUTPUT
        end
    end
end

// Default assignments to prevent latches
assign result_valid = 1'b0;
assign is_possible = 1'b0;
assign sol_vals = 0;
assign sol_signs = 0;
assign num_terms = 4'd0;

endmodule