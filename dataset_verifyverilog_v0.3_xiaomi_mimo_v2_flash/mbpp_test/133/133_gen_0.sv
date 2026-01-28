module sum_negative_numbers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire signed [7:0] arr_0,
    input wire signed [7:0] arr_1,
    input wire signed [7:0] arr_2,
    input wire signed [7:0] arr_3,
    input wire signed [7:0] arr_4,
    input wire signed [7:0] arr_5,
    input wire signed [7:0] arr_6,
    input wire signed [7:0] arr_7,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CALC = 2'b01;
    localparam [1:0] FINISH = 2'b10;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg signed [15:0] sum;
    reg signed [15:0] current_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'b0;
            sum <= 16'sd0;
            result <= 16'sd0;
            done <= 1'b0;
            current_val <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'b0;
                    sum <= 16'sd0;
                    if (start) begin
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    if (index < len && index < 4'd8) begin
                        // Get current array element and sign-extend
                        case (index)
                            4'd0: current_val <= {{8{arr_0[7]}}, arr_0};
                            4'd1: current_val <= {{8{arr_1[7]}}, arr_1};
                            4'd2: current_val <= {{8{arr_2[7]}}, arr_2};
                            4'd3: current_val <= {{8{arr_3[7]}}, arr_3};
                            4'd4: current_val <= {{8{arr_4[7]}}, arr_4};
                            4'd5: current_val <= {{8{arr_5[7]}}, arr_5};
                            4'd6: current_val <= {{8{arr_6[7]}}, arr_6};
                            4'd7: current_val <= {{8{arr_7[7]}}, arr_7};
                            default: current_val <= 16'sd0;
                        endcase
                        
                        // Add if negative (MSB is 1)
                        if (current_val[15]) begin
                            sum <= sum + current_val;
                        end
                        
                        index <= index + 1'b1;
                    end else begin
                        state <= FINISH;
                        result <= sum;
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