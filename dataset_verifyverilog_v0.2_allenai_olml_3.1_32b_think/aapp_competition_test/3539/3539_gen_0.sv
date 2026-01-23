module bipartite_battle (input clk, input rst_n, input start, output reg [31:0] result, output reg done);

parameter N = 1;
parameter MAX_VERTICES = 3;
localparam GRAPH_SIZE = MAX_VERTICES * MAX_VERTICES; // 9 bits
localparam TOTAL_GRAPHS = (1 << GRAPH_SIZE); // 512

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

reg [2:0] state_reg;
reg [2:0] state;

reg [8:0] counter;
reg [31:0] total_losing;
reg [3:0] popcount_val; // Computed as combinatorial

// Combinatorial block to compute popcount
always @(*) begin
    popcount_val = counter[8] + counter[7] + counter[6] + counter[5] + counter[4] + counter[3] + counter[2] + counter[1] + counter[0];
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        counter <= 0;
        total_losing <= 0;
        done <= 0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= PROCESSING;
                    counter <= 0;
                    total_losing <= 0;
                end
            end
            PROCESSING: begin
                if (counter < TOTAL_GRAPHS) begin
                    if (popcount_val == 0) begin
                        total_losing = total_losing + 1;
                    end
                    counter <= counter + 1;
                end else begin
                    state_reg <= DONE;
                    done <= 1;
                    result <= total_losing;
                end
            end
            DONE: begin
                // Stay in DONE
            end
        endcase
    end
end
endmodule