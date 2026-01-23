module sum_range_list (
    input clk,
    input rst_n,
    input start,
    input [3:0] m,
    input [3:0] n,
    input [7:0] list1 [11:0],
    output reg [10:0] result,
    output reg done
);
localparam IDLE = 2'd0,
         PROCESSING = 2'd1,
         DONE = 2'd2;

reg [1:0] state;
reg [3:0] m_reg, n_reg;
reg [10:0] sum_reg;
reg [3:0] cycle_count;

// Asynchronous reset
always @(*) begin
    if (!rst_n) begin
        state <= IDLE;
        m_reg <= 4'd0;
        n_reg <= 4'd0;
        sum_reg <= 11'd0;
        cycle_count <= 4'd0;
    end
end

// Combinatorial output assignments
assign result = (state == DONE) ? sum_reg : 11'd0;
assign done = (state == DONE);

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            m_reg <= m;
            n_reg <= n;
            sum_reg <= 11'd0;
            cycle_count <= 4'd0;
            state <= PROCESSING;
        end
    end else if (state == PROCESSING) begin
        // Accumulate sum if within range
        if (cycle_count < 12) begin
            integer current_index;
            current_index = cycle_count;
            if (current_index >= m_reg && current_index <= n_reg) begin
                sum_reg <= sum_reg + list1[current_index];
            end
        end
        // Increment cycle counter
        cycle_count <= cycle_count + 1;
        // Check transitions
        if (cycle_count == 12) begin
            state <= DONE;
        end else if (!start) begin
            state <= IDLE;
        end
    end else if (state == DONE) begin
        if (!start) begin
            state <= IDLE;
        end
    end
end

endmodule