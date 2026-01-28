module elementwise_division #(
    parameter NUM_ELEMENTS = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input arrays - individual ports
    input wire [DATA_WIDTH-1:0] dividend_0,
    input wire [DATA_WIDTH-1:0] dividend_1,
    input wire [DATA_WIDTH-1:0] dividend_2,
    input wire [DATA_WIDTH-1:0] dividend_3,
    
    input wire [DATA_WIDTH-1:0] divisor_0,
    input wire [DATA_WIDTH-1:0] divisor_1,
    input wire [DATA_WIDTH-1:0] divisor_2,
    input wire [DATA_WIDTH-1:0] divisor_3,
    
    // Output arrays - individual ports
    output reg [RESULT_WIDTH-1:0] result_0,
    output reg [RESULT_WIDTH-1:0] result_1,
    output reg [RESULT_WIDTH-1:0] result_2,
    output reg [RESULT_WIDTH-1:0] result_3,
    
    output reg done
);

    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [1:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational division results
    wire [RESULT_WIDTH-1:0] div_result_0;
    wire [RESULT_WIDTH-1:0] div_result_1;
    wire [RESULT_WIDTH-1:0] div_result_2;
    wire [RESULT_WIDTH-1:0] div_result_3;
    
    assign div_result_0 = (divisor_0 != 0) ? dividend_0 / divisor_0 : 0;
    assign div_result_1 = (divisor_1 != 0) ? dividend_1 / divisor_1 : 0;
    assign div_result_2 = (divisor_2 != 0) ? dividend_2 / divisor_2 : 0;
    assign div_result_3 = (divisor_3 != 0) ? dividend_3 / divisor_3 : 0;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 2'd0;
            done <= 1'b0;
            result_0 <= 0;
            result_1 <= 0;
            result_2 <= 0;
            result_3 <= 0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 2'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Store results sequentially
                    case (index)
                        2'd0: result_0 <= div_result_0;
                        2'd1: result_1 <= div_result_1;
                        2'd2: result_2 <= div_result_2;
                        2'd3: result_3 <= div_result_3;
                    endcase
                    
                    if (index == 2'd3 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        index <= 2'd0;
                    end else begin
                        index <= index + 2'd1;
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