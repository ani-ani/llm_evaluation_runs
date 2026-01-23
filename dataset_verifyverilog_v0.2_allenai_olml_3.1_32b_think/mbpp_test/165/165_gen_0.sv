module count_char_position (
    input clk,
    input rst_n, // active-low
    input start,
    input [63:0] str_data,
    output reg [2:0] count,
    output reg done
);

// Declare registers
reg [2:0] count_reg;
reg [2:0] pos_counter;
reg [1:0] state;
reg start_edge;
reg done_reg;

// State definitions
localparam IDLE = 2'b00;
localparam WAIT = 2'b01;
localparam PROCESSING = 2'b10;

// Start edge detection (synchronous)
always @(posedge clk) begin
    if (!rst_n) begin
        start_edge <= 0;
    end else begin
        if (start && !start_edge) begin
            start_edge <= 1;
        end else begin
            start_edge <= 0;
        end
    end
end

// Main state machine and logic (synchronous)
always @(posedge clk) begin
    if (!rst_n) begin
        count_reg <= 0;
        pos_counter <= 0;
        state <= IDLE;
        done_reg <= 0;
        start_edge <= 0;
    end else begin
        if (state == IDLE) begin
            if (start_edge) begin
                state <= WAIT;
            end
        end
        if (state == WAIT) begin
            state <= PROCESSING;
            pos_counter <= 0;
        end
        if (state == PROCESSING) begin
            if (pos_counter < 8) begin
                int position;
                position = pos_counter;
                int char_val;
                char_val = str_data >> (position * 8) & 8'hFF;
                if (char_val == ('A' + position) || char_val == ('a' + position)) begin
                    count_reg <= count_reg + 1;
                end
                pos_counter <= pos_counter + 1;
            end else begin
                done_reg <= 1;
                state <= IDLE;
                pos_counter <= 0;
            end
        end
    end
end

// Assign outputs
assign count = count_reg;
assign done = done_reg;

endmodule