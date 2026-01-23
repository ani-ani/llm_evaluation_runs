module digit_counter (
    input clk,
    input rst_n, // active low
    input start,
    input [7:0] char_in,
    output reg [4:0] count,
    output reg done,
    output reg [4:0] addr_out
);

// Internal registers
reg [4:0] addr;
reg [4:0] count;
reg [2:0] state;
reg is_digit;

// Combinational assignments
assign addr_out = (state == 3'b000 || state == 3'b100) ? 5'b0 : addr;

always @(negedge rst_n) begin
    addr <= 5'b0;
    count <= 5'b0;
    state <= 3'b000;
    is_digit <= 1'b0;
    done <= 1'b0;
end

// State machine and control logic
always @(posedge clk) begin
    // Reset on start signal (synchronously)
    if (start) begin
        count <= 5'b0;
        addr <= 5'b0;
    end

    // State transitions
    if (state == 3'b000) begin // IDLE
        if (start) begin
            state <= 3'b001; // READ_CHAR
        end
    end else if (state == 3'b001) begin // READ_CHAR
        state <= 3'b010; // CHECK
    end else if (state == 3'b010) begin // CHECK
        is_digit <= (char_in >= 8'h30 && char_in <= 8'h39);
        state <= 3'b011; // UPDATE
    end else if (state == 3'b011) begin // UPDATE
        if (is_digit) begin
            count <= count + 1;
        end
        addr <= addr + 1;
        if (addr == 5'b0) begin // indicates we were at 15 before increment
            state <= 3'b100; // FINISH
        end else begin
            state <= 3'b001; // READ_CHAR for next address
        end
    end else if (state == 3'b100) begin // FINISH
        done <= 1'b1;
        state <= 3'b100; // stay
    end
end

endmodule