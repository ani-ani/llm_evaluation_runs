module elementwise_division #(
    parameter NUM_ELEMENTS = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [DATA_WIDTH-1:0] dividend_0,
    input wire [DATA_WIDTH-1:0] dividend_1,
    input wire [DATA_WIDTH-1:0] dividend_2,
    input wire [DATA_WIDTH-1:0] dividend_3,
    
    input wire [DATA_WIDTH-1:0] divisor_0,
    input wire [DATA_WIDTH-1:0] divisor_1,
    input wire [DATA_WIDTH-1:0] divisor_2,
    input wire [DATA_WIDTH-1:0] divisor_3,
    
    output reg [RESULT_WIDTH-1:0] result_0,
    output reg [RESULT_WIDTH-1:0] result_1,
    output reg [RESULT_WIDTH-1:0] result_2,
    output reg [RESULT_WIDTH-1:0] result_3,
    
    output reg done
);

    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [1:0] index;
    
    wire [RESULT_WIDTH-1:0] div_result [0:3];
    
    assign div_result[0] = (divisor_0 == 8'd0) ? 8'd0 : dividend_0 / divisor_0;
    assign div_result[1] = (divisor_1 == 8'd0) ? 8'd0 : dividend_1 / divisor_1;
    assign div_result[2] = (divisor_2 == 8'd0) ? 8'd0 : dividend_2 / divisor_2;
    assign div_result[3] = (divisor_3 == 8'd0) ? 8'd0 : dividend_3 / divisor_3;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            index    <= 2'd0;
            done     <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 2'd0;
                    end
                end
                
                COMPUTE: begin
                    case (index)
                        2'd0: result_0 <= div_result[0];
                        2'd1: result_1 <= div_result[1];
                        2'd2: result_2 <= div_result[2];
                        2'd3: result_3 <= div_result[3];
                    endcase
                    
                    if (index == 2'd3) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 2'd1;
                    end
                end
                
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule