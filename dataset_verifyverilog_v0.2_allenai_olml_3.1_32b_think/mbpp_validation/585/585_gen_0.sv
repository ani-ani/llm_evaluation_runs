module top_items_finder (
input clk,
input rst_n, // active-low reset
input start,
input [2:0] n,
input [7:0][63:0] items,
output reg [2:0] done_items,
output reg [7:0][63:0] result,
output reg done
);

// Internal registers
reg [2:0] state, subcounter;
reg [63:0] items_reg [7:0];
reg [2:0] done_items_reg;
reg [7:0][63:0] result_reg;
reg prev_start;
reg [2:0] n_reg;

// Parameters for states
localparam IDLE = 3'd0,
        LOAD = 3'd1,
        SORT = 3'd2,
        OUTPUT = 3'd3,
        DONE = 3'd4;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        subcounter <= 3'd0;
        items_reg <= 64'd0;
        done_items_reg <= 3'd0;
        result_reg <= 64'd0;
        prev_start <= 1'b0;
        n_reg <= 3'd0;
    end else begin
        // State machine logic
        if (state == IDLE) begin
            if (start && !prev_start) begin
                state <= LOAD;
                prev_start <= 1'b1;
            end
        end else if (state == LOAD) begin
            items_reg <= items;
            n_reg <= n;
            state <= SORT;
            subcounter <= 3'd0;
            prev_start <= 1'b0; // reset for next start
        end else if (state == SORT) begin
            if (subcounter < 6) begin
                case (subcounter)
                    0: begin
                        integer swap01 = (items_reg[0][63:32] < items_reg[1][63:32]);
                        integer swap23 = (items_reg[2][63:32] < items_reg[3][63:32]);
                        items_reg[0] <= swap01 ? items_reg[1] : items_reg[0];
                        items_reg[1] <= swap01 ? items_reg[0] : items_reg[1];
                        items_reg[2] <= swap23 ? items_reg[3] : items_reg[2];
                        items_reg[3] <= swap23 ? items_reg[2] : items_reg[3];
                        subcounter <= subcounter +1;
                    end
                    1: begin
                        integer swap45 = (items_reg[4][63:32] < items_reg[5][63:32]);
                        integer swap67 = (items_reg[6][63:32] < items_reg[7][63:32]);
                        items_reg[4] <= swap45 ? items_reg[5] : items_reg[4];
                        items_reg[5] <= swap45 ? items_reg[4] : items_reg[5];
                        items_reg[6] <= swap67 ? items_reg[7] : items_reg[6];
                        items_reg[7] <= swap67 ? items_reg[6] : items_reg[7];
                        subcounter <= subcounter +1;
                    end
                    2: begin
                        integer swap02 = (items_reg[0][63:32] < items_reg[2][63:32]);
                        integer swap13 = (items_reg[1][63:32] < items_reg[3][63:32]);
                        items_reg[0] <= swap02 ? items_reg[2] : items_reg[0];
                        items_reg[2] <= swap02 ? items_reg[0] : items_reg[2];
                        items_reg[1] <= swap13 ? items_reg[3] : items_reg[1];
                        items_reg[3] <= swap13 ? items_reg[1] : items_reg[3];
                        subcounter <= subcounter +1;
                    end
                    3: begin
                        integer swap46 = (items_reg[4][63:32] < items_reg[6][63:32]);
                        integer swap57 = (items_reg[5][63:32] < items_reg[7][63:32]);
                        items_reg[4] <= swap46 ? items_reg[6] : items_reg[4];
                        items_reg[6] <= swap46 ? items_reg[4] : items_reg[6];
                        items_reg[5] <= swap57 ? items_reg[7] : items_reg[5];
                        items_reg[7] <= swap57 ? items_reg[5] : items_reg[7];
                        subcounter <= subcounter +1;
                    end
                    4: begin
                        integer swap04 = (items_reg[0][63:32] < items_reg[4][63:32]);
                        integer swap15 = (items_reg[1][63:32] < items_reg[5][63:32]);
                        items_reg[0] <= swap04 ? items_reg[4] : items_reg[0];
                        items_reg[4] <= swap04 ? items_reg[0] : items_reg[4];
                        items_reg[1] <= swap15 ? items_reg[5] : items_reg[1];
                        items_reg[5] <= swap15 ? items_reg[1] : items_reg[5];
                        subcounter <= subcounter +1;
                    end
                    5: begin
                        integer swap26 = (items_reg[2][63:32] < items_reg[6][63:32]);
                        integer swap37 = (items_reg[3][63:32] < items_reg[7][63:32]);
                        items_reg[2] <= swap26 ? items_reg[6] : items_reg[2];
                        items_reg[6] <= swap26 ? items_reg[2] : items_reg[6];
                        items_reg[3] <= swap37 ? items_reg[7] : items_reg[3];
                        items_reg[7] <= swap37 ? items_reg[3] : items_reg[7];
                        subcounter <= subcounter +1;
                    end
                    default: subcounter <= subcounter +1;
                endcase
            end else begin
                state <= OUTPUT;
                subcounter <= 3'd0;
            end
        end else if (state == OUTPUT) begin
            // Assign result_reg based on n_reg
            case (n_reg)
                1: result_reg <= { items_reg[0], 7{64'd0} };
                2: result_reg <= { items_reg[0], items_reg[1], 6{64'd0} };
                3: result_reg <= { items_reg[0], items_reg[1], items_reg[2], 5{64'd0} };
                default: result_reg <= 8{64'd0};
            endcase
            done_items_reg <= n_reg;
            state <= DONE;
        end else if (state == DONE) begin
            // Stay in DONE, no action needed
            if (start && !prev_start) begin
                // Optionally allow restart, but spec doesn't mention, so ignore
            end
        end
    end
end // always @(posedge clk)

// Combinatorial outputs
assign done_items = done_items_reg;
assign result = result_reg;
assign done = (state == DONE);

endmodule