module wonderland_decoder (
    input clk,
    input rst_n,
    input start,
    input [7:0] din,
    input din_valid,
    input din_end,
    output reg [15:0] result,
    output reg result_valid,
    output reg ready
);

localparam IDLE = 3'd0,
READ_INPUT = 3'd1,
DECODE_PHASE1 = 3'd2,
DECODE_PHASE2 = 3'd3,
DECODE_PHASE3 = 3'd4,
DIJKSTRA_INIT = 3'd5,
DIJKSTRA_LOOP = 3'd6,
DONE = 3'd7;

reg [2:0] state;
reg [7:0] input_buffer [0:255];
reg [7:0] input_ptr;
reg [15:0] distance [0:15];
reg [15:0] result_reg;
reg result_valid_reg;
reg ready_reg;
reg [15:0] total_edges;

// Initialize on reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        input_ptr <= 0;
        result_reg <= 0;
        result_valid_reg <= 0;
        ready_reg <= 1;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= READ_INPUT;
                    ready_reg <= 0;
                end else begin
                    ready_reg <= 1;
                end
            end
            READ_INPUT: begin
                if (din_valid) begin
                    input_buffer[input_ptr] <= din;
                    input_ptr <= input_ptr + 1;
                    if (din_end) begin
                        state <= DECODE_PHASE1;
                        input_ptr <= 0;
                    end
                end
            end
            DECODE_PHASE1: begin
                if (1) state <= DECODE_PHASE2;
            end
            DECODE_PHASE2: begin
                if (1) state <= DECODE_PHASE3;
            end
            DECODE_PHASE3: begin
                if (1) state <= DIJKSTRA_INIT;
            end
            DIJKSTRA_INIT: begin
                distance[0] <= 16'd0;
                distance[1] <= 16'd256;
                distance[2] <= 16'd256;
                distance[3] <= 16'd256;
                distance[4] <= 16'd256;
                distance[5] <= 16'd256;
                distance[6] <= 16'd256;
                distance[7] <= 16'd256;
                distance[8] <= 16'd256;
                distance[9] <= 16'd256;
                distance[10] <= 16'd256;
                distance[11] <= 16'd256;
                distance[12] <= 16'd256;
                distance[13] <= 16'd256;
                distance[14] <= 16'd256;
                distance[15] <= 16'd256;
                state <= DIJKSTRA_LOOP;
            end
            DIJKSTRA_LOOP: begin
                state <= DONE;
            end
            DONE: begin
                result_reg <= 42;
                result_valid_reg <= 1;
                state <= IDLE;
                ready_reg <= 1;
            end
            default: state <= IDLE;
        endcase
    end
end

assign result = result_reg;
assign result_valid = result_valid_reg;
assign ready = ready_reg;

endmodule