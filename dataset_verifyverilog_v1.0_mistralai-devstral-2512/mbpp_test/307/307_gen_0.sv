module colon_tuplex(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuplex_str_0,
    input wire [7:0] tuplex_str_1,
    input wire [7:0] tuplex_str_2,
    input wire [7:0] tuplex_str_3,
    input wire [7:0] tuplex_str_4,
    input wire [7:0] tuplex_str_5,
    input wire [7:0] tuplex_str_6,
    input wire [7:0] tuplex_str_7,
    input wire [7:0] tuplex_int,
    input wire [7:0] tuplex_list_0,
    input wire [7:0] tuplex_list_1,
    input wire [7:0] tuplex_list_2,
    input wire [7:0] tuplex_list_3,
    input wire tuplex_bool,
    input wire [1:0] m,
    input wire [7:0] n,
    output reg [7:0] result_str_0,
    output reg [7:0] result_str_1,
    output reg [7:0] result_str_2,
    output reg [7:0] result_str_3,
    output reg [7:0] result_str_4,
    output reg [7:0] result_str_5,
    output reg [7:0] result_str_6,
    output reg [7:0] result_str_7,
    output reg [7:0] result_int,
    output reg [7:0] result_list_0,
    output reg [7:0] result_list_1,
    output reg [7:0] result_list_2,
    output reg [7:0] result_list_3,
    output reg result_bool,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_str_0 <= 8'd0;
            result_str_1 <= 8'd0;
            result_str_2 <= 8'd0;
            result_str_3 <= 8'd0;
            result_str_4 <= 8'd0;
            result_str_5 <= 8'd0;
            result_str_6 <= 8'd0;
            result_str_7 <= 8'd0;
            result_int <= 8'd0;
            result_list_0 <= 8'd0;
            result_list_1 <= 8'd0;
            result_list_2 <= 8'd0;
            result_list_3 <= 8'd0;
            result_bool <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    result_str_0 <= tuplex_str_0;
                    result_str_1 <= tuplex_str_1;
                    result_str_2 <= tuplex_str_2;
                    result_str_3 <= tuplex_str_3;
                    result_str_4 <= tuplex_str_4;
                    result_str_5 <= tuplex_str_5;
                    result_str_6 <= tuplex_str_6;
                    result_str_7 <= tuplex_str_7;
                    result_int <= tuplex_int;
                    result_bool <= tuplex_bool;
                    
                    if (m == 2'd2) begin
                        result_list_0 <= tuplex_list_1;
                        result_list_1 <= tuplex_list_2;
                        result_list_2 <= tuplex_list_3;
                        result_list_3 <= n;
                    end else begin
                        result_list_0 <= tuplex_list_0;
                        result_list_1 <= tuplex_list_1;
                        result_list_2 <= tuplex_list_2;
                        result_list_3 <= tuplex_list_3;
                    end
                    
                    if (cycle_count >= MAX_CYCLES - 8'd1) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule