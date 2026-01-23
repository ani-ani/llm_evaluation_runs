module decomposition_counter (input clk, input rst_n, input start, input [15:0] data_in, input [1:0] n_in, input valid_in, input last_in, output reg [31:0] result, output reg done, output reg ready);

localparam MOD = 1000000007;
localparam int prime_list[54] = {2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,251};

reg [8:0] total_exponents [53:0];
reg [2:0] state;
reg [2:0] n_in_reg;
reg [3:0] count;
reg [31:0] result_reg;
reg done_reg;
reg ready_reg;

localparam state_t IDLE = 3'd0,
               FACTORIZE = 3'd1,
               COMPUTE = 3'd2,
               DONE = 3'd3;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        n_in_reg <= 4'd0;
        count <= 4'd0;
        for (int i=0; i<54; i++) total_exponents[i] <= 0;
        result_reg <= 0;
        done_reg <= 0;
        ready_reg <= 1;
    end else begin
        state <= state;
        ready_reg <= (state == IDLE || state == DONE) ? 1 : 0;
        done_reg <= (state == DONE) ? 1 : 0;
        result_reg <= (state == COMPUTE || state == DONE) ? result_reg : 0;

        case (state)
            IDLE: begin
                if (start) begin
                    n_in_reg <= n_in;
                    if (n_in < 1 || n_in >4) n_in_reg <= 4'd1;
                    count <= 4'd0;
                    state <= FACTORIZE;
                end
            end
            FACTORIZE: begin
                if (valid_in) begin
                    if (count < n_in_reg) begin
                        // Factorization logic goes here
                        count <= count + 1;
                        if (count == n_in_reg && last_in) state <= COMPUTE;
                    end
                end
            end
            COMPUTE: begin
                // Compute result here
                result_reg <= 1; // Placeholder
                state <= DONE;
            end
            DONE: begin
                // Latch result
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;
assign ready = ready_reg;

endmodule