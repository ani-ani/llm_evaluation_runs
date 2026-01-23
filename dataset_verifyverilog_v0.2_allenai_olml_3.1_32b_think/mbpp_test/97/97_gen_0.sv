module frequency_counter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] row_idx,
    input [7:0] data_in,
    output reg [7:0] freq_value,
    output reg [7:0] key_out,
    output reg done,
    output reg valid
);

reg [7:0] ram [0:255];

reg [2:0] state;
localparam IDLE = 3'b000, LOAD_ROW = 3'b001, COUNTING = 3'b010, FINISHED = 3'b011, READOUT = 3'b100;

reg [23:0] element_counter;
reg [5:0] start_timer;
reg [7:0] current_key;
reg [7:0] readout_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        element_counter <= 24'b0;
        start_timer <= 6'b0;
        current_key <= 8'b0;
        readout_counter <= 8'b0;
        done <= 1'b0;
        valid <= 1'b0;
        freq_value <= 8'b0;
        key_out <= 8'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_ROW;
                    element_counter <= 24'b0;
                end else begin
                    state <= IDLE;
                end
            end
            LOAD_ROW: begin
                state <= COUNTING;
            end
            COUNTING: begin
                if (element_counter < 24) begin
                    ram[data_in] <= ram[data_in] + 1;
                    element_counter <= element_counter + 1;
                end
                if (element_counter == 24) begin
                    state <= FINISHED;
                    start_timer <= 6'b0;
                end
            end
            FINISHED: begin
                if (start_timer < 6) begin
                    start_timer <= start_timer + 1;
                end else begin
                    state <= READOUT;
                    done <= 1'b1;
                end
            end
            READOUT: begin
                freq_value <= ram[current_key];
                key_out <= current_key;
                valid <= 1'b1;
                current_key <= current_key + 1;
                if (current_key == 256) begin
                    current_key <= 8'b0;
                    readout_counter <= readout_counter + 1;
                end
            end
        endcase
    end
end
endmodule