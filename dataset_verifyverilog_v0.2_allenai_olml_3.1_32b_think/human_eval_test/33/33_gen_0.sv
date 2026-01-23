module sort_third (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in [7:0],
    output reg [7:0] data_out [7:0],
    output reg done
);

// Internal registers
reg [7:0] data_reg [7:0];
reg [7:0] registered_sorted [7:0];
reg [7:0] counter;
reg done_reg;

// Combinational block to compute sorted_array from data_in
wire [7:0] sorted_array;
wire [7:0] a, b, c;
always @(*) begin
    a = data_in[0];
    b = data_in[3];
    c = data_in[6];
    if (a > b) begin
        {a, b} = {b, a};
    end
    if (b > c) begin
        {b, c} = {c, b};
    end
    if (a > b) begin
        {a, b} = {b, a};
    end
    sorted_array = {a, data_in[1], data_in[2], b, data_in[4], data_in[5], c, data_in[7]};
end

// Clock domain registers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_reg <= 0;
        registered_sorted <= 0;
        counter <= 0;
        done_reg <= 0;
    end else begin
        if (start) begin
            data_reg <= data_in;
            registered_sorted <= sorted_array;
        end
        if (counter == 0) begin
            done_reg <= 1;
        end else begin
            done_reg <= 0;
        end
        counter <= counter == 0 ? 0 : counter - 1;
        if (start) begin
            counter <= 20;
        end
    end
end

assign data_out = done_reg ? registered_sorted : data_reg;
assign done = done_reg;

endmodule