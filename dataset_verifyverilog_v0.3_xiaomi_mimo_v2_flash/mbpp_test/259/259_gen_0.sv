module max_tuple_elements (
    // Clock and reset
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input tuples: 4 rows x 2 columns of 8-bit values
    // Input format: arr_0_0, arr_0_1, arr_1_0, arr_1_1, ... arr_3_1
    input wire [7:0] arr_0_0, arr_0_1,
    input wire [7:0] arr_1_0, arr_1_1,
    input wire [7:0] arr_2_0, arr_2_1,
    input wire [7:0] arr_3_0, arr_3_1,
    
    // Second tuple (parallel inputs)
    input wire [7:0] brr_0_0, brr_0_1,
    input wire [7:0] brr_1_0, brr_1_1,
    input wire [7:0] brr_2_0, brr_2_1,
    input wire [7:0] brr_3_0, brr_3_1,
    
    // Outputs: 4 rows x 2 columns of maximized values
    output reg [7:0] result_0_0, result_0_1,
    output reg [7:0] result_1_0, result_1_1,
    output reg [7:0] result_2_0, result_2_1,
    output reg [7:0] result_3_0, result_3_1,
    
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] COMPLETE = 2'b10;
    
    reg [1:0] state, next_state;
    
    // Combinational max logic (single cycle for all elements)
    wire [7:0] max_0_0, max_0_1;
    wire [7:0] max_1_0, max_1_1;
    wire [7:0] max_2_0, max_2_1;
    wire [7:0] max_3_0, max_3_1;
    
    assign max_0_0 = (arr_0_0 > brr_0_0) ? arr_0_0 : brr_0_0;
    assign max_0_1 = (arr_0_1 > brr_0_1) ? arr_0_1 : brr_0_1;
    assign max_1_0 = (arr_1_0 > brr_1_0) ? arr_1_0 : brr_1_0;
    assign max_1_1 = (arr_1_1 > brr_1_1) ? arr_1_1 : brr_1_1;
    assign max_2_0 = (arr_2_0 > brr_2_0) ? arr_2_0 : brr_2_0;
    assign max_2_1 = (arr_2_1 > brr_2_1) ? arr_2_1 : brr_2_1;
    assign max_3_0 = (arr_3_0 > brr_3_0) ? arr_3_0 : brr_3_0;
    assign max_3_1 = (arr_3_1 > brr_3_1) ? arr_3_1 : brr_3_1;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = COMPLETE;
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_0_0 <= 8'b0; result_0_1 <= 8'b0;
            result_1_0 <= 8'b0; result_1_1 <= 8'b0;
            result_2_0 <= 8'b0; result_2_1 <= 8'b0;
            result_3_0 <= 8'b0; result_3_1 <= 8'b0;
            done <= 1'b0;
        end else begin
            case (state)
                COMPUTE: begin
                    result_0_0 <= max_0_0;
                    result_0_1 <= max_0_1;
                    result_1_0 <= max_1_0;
                    result_1_1 <= max_1_1;
                    result_2_0 <= max_2_0;
                    result_2_1 <= max_2_1;
                    result_3_0 <= max_3_0;
                    result_3_1 <= max_3_1;
                    done <= 1'b1;
                end
                COMPLETE, IDLE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule