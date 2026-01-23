module hash_word_counter(input clk, input rst_n, // active low, input start, input [4:0] N, input [24:0] K, input [4:0] M, output reg [31:0] result, output reg done);

localparam MAX_M = 2;
localparam ADDR_WIDTH = (1 << MAX_M);

reg [31:0] result_reg;
reg done_reg;
reg [4:0] m_adjusted;
reg [4:0] current_step;
reg [ADDR_WIDTH-1:0] addr_cnt;
reg [4:0] char_cnt;
reg [2:0] state; // IDLE=0, INIT=1, PROCESSING=2, DONE=3

reg [31:0] dp_prev [ADDR_WIDTH];
reg [31:0] dp_next [ADDR_WIDTH];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_reg <= 32'b0;
        done_reg <= 1'b0;
        m_adjusted <= M < MAX_M ? M : MAX_M;
        current_step <= 5'd0;
        addr_cnt <= {ADDR_WIDTH{1'b0}};
        char_cnt <= 5'd0;
        state <= 3'd0;
        // Unrolled initialization for ADDR_WIDTH=4
        dp_prev[0] <= 32'b0;
        dp_prev[1] <= 32'b0;
        dp_prev[2] <= 32'b0;
        dp_prev[3] <= 32'b0;
        dp_next[0] <= 32'b0;
        dp_next[1] <= 32'b0;
        dp_next[2] <= 32'b0;
        dp_next[3] <= 32'b0;
    end else begin
        case (state)
            3'd0: // IDLE
                if (start) begin
                    state <= 3'd1; // INIT
                    // Initialize DP: step 0
                    dp_prev[0] <= 32'b1;
                    dp_prev[1] <= 32'b0;
                    dp_prev[2] <= 32'b0;
                    dp_prev[3] <= 32'b0;
                end
                done_reg <= 1'b0;
                result_reg <= 32'b0;
            3'd1: // INIT: maybe just transition
                if (current_step == 5'd0) begin
                    current_step <= 1'd1;
                    state <= 3'd2; // PROCESSING
                end
                done_reg <= 1'b0;
                result_reg <= 32'b0;
            3'd2: // PROCESSING
                // Here, implement the DP steps
                // For now, just increment step and transition to DONE when done
                if (current_step <= N) begin
                    current_step <= current_step + 1;
                    if (current_step > N) begin
                        state <= 3'd3;
                        // Read result
                        result_reg <= dp_prev[K < ADDR_WIDTH ? K : ADDR_WIDTH-1];
                    end
                end
                done_reg <= (state == 3'd3) ? 1'b1 : 1'b0;
            3'd3: // DONE
                // stay here
                state <= 3'd3;
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule