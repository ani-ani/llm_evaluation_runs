module top_module (
    input wire clk,
    input wire reset,
    input wire [7:0] data_in,
    output reg [7:0] data_out
);

    // Internal registers
    reg [7:0] reg_data;

    // Always block for data processing
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_data <= 8'h00;
        end else begin
            reg_data <= data_in;
        end
    end

    // Assign output
    assign data_out = reg_data;

endmodule