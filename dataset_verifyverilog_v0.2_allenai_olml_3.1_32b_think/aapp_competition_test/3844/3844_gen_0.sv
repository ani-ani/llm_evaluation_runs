module card_game(input clk, input rst_n, input start, input [7:0] data_in [15:0], output reg result, output reg done);
localparam N = 16;
localparam IDLE = 2'd0;
localparam FIND_MAX = 2'd1;
localparam COUNT_MAX = 2'd2;
localparam DONE_STATE = 2'd3;

// Internal registers
reg [1:0] state;
reg [7:0] max_val;
reg [3:0] index;
reg [7:0] count;
reg result_reg; // to hold the final result

// Combinational done
assign done = (state == DONE_STATE);

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        max_val <= 8'b0;
        index <= 4'b0;
        count <= 8'b0;
        result_reg <= 1'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= FIND_MAX;
                    max_val <= 8'b0;
                    index <= 4'b0;
                end else begin
                    state <= IDLE;
                end
            end
            FIND_MAX: begin
                if (index == N-1) begin // 15
                    if (data_in[index] > max_val) 
                        max_val <= data_in[index];
                    state <= COUNT_MAX;
                    index <= 4'b0; // reset for COUNT_MAX
                end else begin
                    if (data_in[index] > max_val) 
                        max_val <= data_in[index];
                    index <= index + 1;
                end
            end
            COUNT_MAX: begin
                if (index == N-1) begin // 15
                    if (data_in[index] == max_val) 
                        count <= count + 1;
                    state <= DONE_STATE;
                end else begin
                    if (data_in[index] == max_val) 
                        count <= count + 1;
                    index <= index + 1;
                end
            end
            DONE_STATE: begin
                // Remain in DONE_STATE
                state <= DONE_STATE;
                result_reg <= count[0]; // LSB is parity
            end
        endcase
    end
end

assign result = result_reg;
endmodule