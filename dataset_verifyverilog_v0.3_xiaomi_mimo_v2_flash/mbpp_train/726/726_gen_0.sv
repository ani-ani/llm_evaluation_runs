module multiply_adjacent (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [3:0] length,
    output reg [15:0] result,
    output reg result_valid,
    output reg done
);

    // State machine states
    reg [2:0] state;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] FINISHED = 3'd3;
    
    // Internal registers
    reg [2:0] index;
    reg [15:0] product_reg;
    reg [7:0] input_data [0:4];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            product_reg <= 16'd0;
            input_data[0] <= 8'd0;
            input_data[1] <= 8'd0;
            input_data[2] <= 8'd0;
            input_data[3] <= 8'd0;
            input_data[4] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    index <= 3'd0;
                    
                    if (start && length >= 4'd2) begin
                        input_data[0] <= arr_0;
                        input_data[1] <= arr_1;
                        input_data[2] <= arr_2;
                        input_data[3] <= arr_3;
                        input_data[4] <= arr_4;
                        state <= COMPUTE;
                    end else if (start && length == 4'd1) begin
                        result <= 16'd0;
                        result_valid <= 1'b1;
                        done <= 1'b1;
                        state <= FINISHED;
                    end
                end
                
                COMPUTE: begin
                    product_reg <= input_data[index] * input_data[index + 3'd1];
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    result <= product_reg;
                    result_valid <= 1'b1;
                    index <= index + 3'd1;
                    
                    if (index >= length - 3'd2) begin
                        done <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                FINISHED: begin
                    if (!start) begin
                        result_valid <= 1'b0;
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule