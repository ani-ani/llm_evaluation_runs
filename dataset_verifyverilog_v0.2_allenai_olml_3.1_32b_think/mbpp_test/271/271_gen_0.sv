module even_power_sum (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [63:0] result,
    output reg done
);

parameter IDLE = 2'd0, COMPUTE = 2'd1, DONE = 2'd2;

reg [1:0] state;
reg [63:0] accum;
reg [4:0] i;
reg [15:0] compute_count;
reg [1:0] setup_counter;

always_ff @(posedge clk) if (!rst_n) begin
    state <= IDLE;
    accum <= 64'b0;
    i <= 5'd1;
    compute_count <= 16'd0;
    setup_counter <= 2'b00;
end else begin
    case (state)
    IDLE: begin
        if (start) begin
            setup_counter <= 2'b10;
            accum <= 64'b0;
            i <= 5'd1;
        end
        if (setup_counter != 2'b00) begin
            setup_counter <= setup_counter - 1;
        end
        if (setup_counter == 2'b00 && start) begin
            state <= COMPUTE;
        end
    end
    COMPUTE: begin
        compute_count <= compute_count + 1;
        if (compute_count == 16) begin
            state <= DONE;
            compute_count <= 16'd0;
        end
        if (i <= n) begin
            accum <= accum + ((((2*i) * (2*i)) * (2*i)) * (2*i)) * (2*i) << 16;
        end
        i <= i + 1;
    end
    DONE: begin
        // Do nothing
    end
    endcase
end

assign result = accum;
assign done = (state == DONE);

endmodule