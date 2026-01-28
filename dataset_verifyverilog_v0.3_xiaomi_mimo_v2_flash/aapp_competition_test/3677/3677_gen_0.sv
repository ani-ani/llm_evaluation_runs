module MAX_CLIQUE_FINDER (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire [3:0] K,
    input wire [63:0] adj_packed,
    output reg [3:0] max_size,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    reg [2:0] state;
    reg [7:0] subset_mask;
    reg [7:0] max_mask;
    reg [3:0] current_size;
    wire is_clique_result;
    wire [3:0] popcount_result;
    wire clique_found_K;

    // Combinational logic for popcount
    reg [3:0] popcount_temp;
    integer i;
    always @(*) begin
        popcount_temp = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < N) begin
                if (subset_mask[i]) begin
                    popcount_temp = popcount_temp + 4'd1;
                end
            end
        end
    end
    assign popcount_result = popcount_temp;

    // Combinational logic for is_clique
    reg is_clique_temp;
    integer j, k;
    always @(*) begin
        is_clique_temp = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < N && subset_mask[i]) begin
                for (j = i + 1; j < 8; j = j + 1) begin
                    if (j < N && subset_mask[j]) begin
                        if (!adj_packed[i*8 + j]) begin
                            is_clique_temp = 1'b0;
                        end
                    end
                end
            end
        end
    end
    assign is_clique_result = is_clique_temp;
    assign clique_found_K = (is_clique_result && (popcount_result == K));

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_size <= 4'd0;
            done <= 1'b0;
            subset_mask <= 8'd0;
            max_mask <= 8'd0;
            current_size <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    subset_mask <= 8'd1;
                    max_size <= 4'd0;
                    // Calculate max_mask = (1 << N) - 1
                    case (N)
                        3'd1: max_mask <= 8'h01;
                        3'd2: max_mask <= 8'h03;
                        3'd3: max_mask <= 8'h07;
                        3'd4: max_mask <= 8'h0F;
                        3'd5: max_mask <= 8'h1F;
                        3'd6: max_mask <= 8'h3F;
                        3'd7: max_mask <= 8'h7F;
                        default: max_mask <= 8'hFF;
                    endcase
                    state <= CHECK;
                end

                CHECK: begin
                    current_size <= popcount_result;
                    state <= UPDATE;
                end

                UPDATE: begin
                    if (is_clique_result) begin
                        if (current_size > max_size) begin
                            max_size <= current_size;
                        end
                        if (clique_found_K) begin
                            max_size <= K;
                            state <= DONE;
                        end else begin
                            state <= INCREMENT;
                        end
                    end else begin
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    if (subset_mask >= max_mask) begin
                        state <= DONE;
                    end else begin
                        subset_mask <= subset_mask + 8'd1;
                        state <= CHECK;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule