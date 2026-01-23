module max_matching (
    input clk,
    input rst_n,
    input start,
    input load_en,
    input [3:0] load_idx,
    input [9:0] load_data,
    output reg [3:0] max_match,
    output reg done,
    output reg valid
);

reg [2:0] state_reg;
reg [2:0] state_reg_next;
reg [3:0] max_match_reg;
reg done_reg;
reg valid_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= 3'd0;
        max_match_reg <= 4'd0;
        done_reg <= 1'b0;
        valid_reg <= 1'b0;
    end else begin
        state_reg <= state_reg;
        max_match_reg <= max_match_reg;
        done_reg <= done_reg;
        valid_reg <= valid_reg;
    end
end

always_comb begin
    max_match = max_match_reg;
    done = done_reg;
    valid = valid_reg;

    state_reg_next = state_reg; // Default hold

    if (state_reg == 3'd0) begin // IDLE
        if (start) begin
            state_reg_next = 3'd2; // BUILD_GRAPH
        end
    end else if (state_reg == 3'd1) begin // LOAD_DATA
        if (load_en) begin
            if (!load_en) begin
                state_reg_next = 3'd0;
            end
        end
    end else if (state_reg == 3'd2) begin // BUILD_GRAPH
        state_reg_next = 3'd3; // FIND_MATCHING
    end else if (state_reg == 3'd3) begin // FIND_MATCHING
        state_reg_next = 3'd4; // UPDATE_MATCHING
    end else if (state_reg == 3'd4) begin // UPDATE_MATCHING
        max_match_reg <= 4'd1;
        done_reg <= 1'b1;
        state_reg_next = 3'd5; // DONE
    end else if (state_reg == 3'd5) begin // DONE
        done_reg <= 1'b1;
        valid_reg <= 1'b1;
        state_reg_next = 3'd5;
    end
end

endmodule