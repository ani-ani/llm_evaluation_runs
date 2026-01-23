module rolling_max(input clk, input rst_n, input start, input [2:0] array_len, input [7:0] input_array [0:7], output reg [7:0] result, output reg [2:0] index, output reg done, output reg valid);
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

reg [7:0] previous_max;
reg [2:0] current_index;
reg [1:0] state;

assign current_max = (input_array[current_index] > previous_max) ? input_array[current_index] : previous_max;
assign result = (state == PROCESSING) ? current_max : 8'b0;
assign index = (state == PROCESSING) ? current_index : 3'b0;
assign done = (state == DONE);
assign valid = (state == PROCESSING);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        previous_max <= 8'b0;
        current_index <= 3'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    if (array_len == 0) begin
                        state <= DONE;
                    end else begin
                        previous_max <= input_array[0];
                        current_index <= 3'b0;
                        state <= PROCESSING;
                    end
                end else begin
                    state <= IDLE;
                end
            end
            PROCESSING: begin
                previous_max <= current_max;
                current_index <= current_index + 1;
                if (current_index + 1 == array_len) begin
                    state <= DONE;
                end else begin
                    state <= PROCESSING;
                end
            end
            DONE: begin
                state <= DONE;
            end
        endcase
    end
end
endmodule