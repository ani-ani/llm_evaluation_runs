module elementwise_subtractor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire signed [7:0] arr1_0,
    input wire signed [7:0] arr1_1,
    input wire signed [7:0] arr1_2,
    input wire signed [7:0] arr1_3,
    input wire signed [7:0] arr1_4,
    input wire signed [7:0] arr1_5,
    input wire signed [7:0] arr1_6,
    input wire signed [7:0] arr1_7,
    input wire signed [7:0] arr2_0,
    input wire signed [7:0] arr2_1,
    input wire signed [7:0] arr2_2,
    input wire signed [7:0] arr2_3,
    input wire signed [7:0] arr2_4,
    input wire signed [7:0] arr2_5,
    input wire signed [7:0] arr2_6,
    input wire signed [7:0] arr2_7,
    output reg signed [7:0] result_0,
    output reg signed [7:0] result_1,
    output reg signed [7:0] result_2,
    output reg signed [7:0] result_3,
    output reg signed [7:0] result_4,
    output reg signed [7:0] result_5,
    output reg signed [7:0] result_6,
    output reg signed [7:0] result_7,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Parallel computation of all elements
                    result_0 <= arr1_0 - arr2_0;
                    result_1 <= arr1_1 - arr2_1;
                    result_2 <= arr1_2 - arr2_2;
                    result_3 <= arr1_3 - arr2_3;
                    result_4 <= arr1_4 - arr2_4;
                    result_5 <= arr1_5 - arr2_5;
                    result_6 <= arr1_6 - arr2_6;
                    result_7 <= arr1_7 - arr2_7;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
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