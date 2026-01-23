module tuple_concat (
    input clk,
    input rst_n,
    input start,
    input [31:0] str0,
    input [31:0] str1,
    input [31:0] str2,
    input [31:0] str3,
    output reg [127:0] result,
    output reg done
);

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

reg [1:0] state;
reg [127:0] result;
reg done;

wire [7:0] str0_c0 = str0[31:24];
wire [7:0] str0_c1 = str0[23:16];
wire [7:0] str0_c2 = str0[15:8];
wire [7:0] str0_c3 = str0[7:0];

wire [7:0] str1_c0 = str1[31:24];
wire [7:0] str1_c1 = str1[23:16];
wire [7:0] str1_c2 = str1[15:8];
wire [7:0] str1_c3 = str1[7:0];

wire [7:0] str2_c0 = str2[31:24];
wire [7:0] str2_c1 = str2[23:16];
wire [7:0] str2_c2 = str2[15:8];
wire [7:0] str2_c3 = str2[7:0];

wire [7:0] str3_c0 = str3[31:24];
wire [7:0] str3_c1 = str3[23:16];
wire [7:0] str3_c2 = str3[15:8];
wire [7:0] str3_c3 = str3[7:0];

wire [151:0] concat_val;
assign concat_val = {
    {str0_c0, str0_c1, str0_c2, str0_c3}, 8'h2D,
    {str1_c0, str1_c1, str1_c2, str1_c3}, 8'h2D,
    {str2_c0, str2_c1, str2_c2, str2_c3}, 8'h2D,
    {str3_c0, str3_c1, str3_c2, str3_c3}
};

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 0;
        done <= 0;
    end else begin
        if (start) begin
            if (state == IDLE) begin
                state <= PROCESSING;
            end
        end
        case (state)
            IDLE: 
                done <= 0;
            PROCESSING: 
                done <= 0;
            DONE: 
                done <= 1;
        endcase
    end
end

always @(*) begin
    if (state == IDLE) begin
        result = 0;
    end else begin
        result = concat_val[151:24];
    end
end

endmodule