module sum_of_maxes (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [511:0] values_packed,
    output reg [31:0] result,
    output reg done
);

// Constants
localparam [31:0] MOD = 32'd1000000007;

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD = 4'd1;
localparam [3:0] SORT_INIT = 4'd2;
localparam [3:0] SORT_COMPARE = 4'd3;
localparam [3:0] SORT_SWAP = 4'd4;
localparam [3:0] SORT_NEXT_INDEX = 4'd5;
localparam [3:0] SORT_NEXT_PASS = 4'd6;
localparam [3:0] COMPUTE = 4'd7;
localparam [3:0] REDUCE = 4'd8;
localparam [3:0] DONE_STATE = 4'd9;

// Internal registers
reg [3:0] state, next_state;
reg [31:0] data_reg [0:15];
reg [3:0] pass_count;
reg [3:0] index_count;
reg [3:0] i_count;
reg [63:0] accumulator;
reg [63:0] product;

// Unpack values
wire [31:0] data [0:15];
generate
    genvar g;
    for (g = 0; g < 16; g = g + 1) begin : unpack
        assign data[g] = values_packed[g*32 +: 32];
    end
endgenerate

// State transition and datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        accumulator <= 64'd0;
        product <= 64'd0;
        pass_count <= 4'd0;
        index_count <= 4'd0;
        i_count <= 4'd0;
        integer idx;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            data_reg[idx] <= 32'd0;
        end
    end else begin
        state <= next_state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    integer idx;
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        data_reg[idx] <= data[idx];
                    end
                end
            end

            LOAD: begin
                if (N <= 1) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = SORT_INIT;
                end
            end

            SORT_INIT: begin
                pass_count <= 4'd0;
                index_count <= 4'd0;
            end

            SORT_COMPARE: begin
                if (data_reg[index_count] > data_reg[index_count + 1]) begin
                    data_reg[index_count] <= data_reg[index_count + 1];
                    data_reg[index_count + 1] <= data_reg[index_count];
                end
            end

            SORT_SWAP: begin
                index_count <= index_count + 1;
            end

            SORT_NEXT_INDEX: begin
                if (index_count < (N - 1 - pass_count)) begin
                    next_state = SORT_COMPARE;
                end else begin
                    next_state = SORT_NEXT_PASS;
                end
            end

            SORT_NEXT_PASS: begin
                pass_count <= pass_count + 1;
                index_count <= 4'd0;
            end

            COMPUTE: begin
                if (i_count >= K - 1) begin
                    product <= {32'd0, data_reg[i_count]};
                    accumulator <= accumulator + product;
                end
                i_count <= i_count + 1;
            end

            REDUCE: begin
                if (accumulator >= MOD) begin
                    accumulator <= accumulator - MOD;
                end
            end

            DONE_STATE: begin
                result <= accumulator[31:0];
                done <= 1'b1;
            end

            default: state <= IDLE;
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = LOAD;
        end

        LOAD: begin
            if (N <= 1) next_state = COMPUTE;
            else next_state = SORT_INIT;
        end

        SORT_INIT: begin
            next_state = SORT_COMPARE;
        end

        SORT_COMPARE: begin
            next_state = SORT_SWAP;
        end

        SORT_SWAP: begin
            next_state = SORT_NEXT_INDEX;
        end

        SORT_NEXT_INDEX: begin
            if (index_count < (N - 1 - pass_count)) next_state = SORT_COMPARE;
            else next_state = SORT_NEXT_PASS;
        end

        SORT_NEXT_PASS: begin
            if (pass_count < N - 1) next_state = SORT_COMPARE;
            else next_state = COMPUTE;
        end

        COMPUTE: begin
            if (i_count >= N) next_state = REDUCE;
            else if (i_count >= K - 1) next_state = COMPUTE;
            else next_state = COMPUTE;
        end

        REDUCE: begin
            if (accumulator >= MOD) next_state = REDUCE;
            else begin
                if (i_count >= N) next_state = DONE_STATE;
                else next_state = COMPUTE;
            end
        end

        DONE_STATE: begin
            next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
end

endmodule