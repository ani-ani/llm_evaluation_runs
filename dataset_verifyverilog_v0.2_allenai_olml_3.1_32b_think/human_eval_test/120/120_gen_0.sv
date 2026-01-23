module maximum_k (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] n,
    input signed [7:0] arr [0:6],
    output reg signed [7:0] result [0:6],
    output reg done
);

reg [2:0] n_reg;
reg [7:0] arr_reg [0:6];
reg [2:0] k_reg;
reg [2:0] state;
reg [7:0] internal_buf [0:6];
reg [2:0] pass_count;
reg [2:0] comp_index;
reg done_reg;
reg [2:0] next_state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_reg <= 3'b000;
        arr_reg <= {7{8'b0}};
        k_reg <= 3'b000;
        state <= 3'b000;
        internal_buf <= {8{9'b0}};
        pass_count <= 3'b000;
        comp_index <= 3'b000;
        done_reg <= 1'b0;
        next_state <= 3'b000;
    end else begin
        if (next_state != state) state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    done_reg = 1'b0;
    case (state)
        3'b000: // IDLE
            if (start) begin
                if (k == 3'b000) begin
                    next_state = 3'b100;
                    done_reg = 1'b1;
                end else begin
                    n_reg <= n;
                    k_reg <= k;
                    arr_reg <= arr;
                    next_state = 3'b001;
                end
            end
        3'b001: // CHECK_DONE
            next_state = 3'b010;
        3'b010: // SORT_PASS
            pass_count <= pass_count + 1;
            if (pass_count > 0) begin
                next_state = 3'b011;
            end
        3'b011: // SELECT_TOP_K
            result <= {7{8'b0}};
            next_state = 3'b100;
        3'b100: // COMPLETE
    endcase
end

assign done = done_reg;
assign result = {7{8'b0}};

endmodule