module odd_xor_pairs (
    input [7:0] data_i,
    input [2:0] idx,
    input valid,
    input done,
    input clk,
    output reg [7:0] result,
    output reg ready
);

    reg [1:0] state;
    reg [2:0] odd_count, even_count;
    reg [7:0] result_reg;
    reg ready_reg;
    reg [1:0] cycle_count;

    parameter IDLE = 2'b00;
    parameter COLLECTING = 2'b01;
    parameter COMPUTING = 2'b10;
    parameter WAITING = 2'b11;

    always @(posedge clk) begin
        if (state == IDLE) begin
            if (valid) begin
                state <= COLLECTING;
                if (data_i[0]) odd_count <= odd_count + 1;
                else even_count <= even_count + 1;
            end
        end else if (state == COLLECTING) begin
            if (valid) begin
                if (data_i[0]) odd_count <= odd_count + 1;
                else even_count <= even_count + 1;
            end else begin
                if (done) begin
                    state <= COMPUTING;
                    result_reg <= odd_count * even_count;
                end else begin
                    state <= IDLE;
                end
            end
        end else if (state == COMPUTING) begin
            state <= WAITING;
        end else if (state == WAITING) begin
            ready_reg <= 1'b1;
            state <= IDLE;
        end
    end

    always @(posedge clk) begin
        if (state != IDLE && state != COLLECTING && state != COMPUTING && state != WAITING) begin
            state <= IDLE;
        end
        if (state == IDLE) begin
            odd_count <= 3'b000;
            even_count <= 3'b000;
        end
    end

    assign result = result_reg;
    assign ready = ready_reg;

endmodule