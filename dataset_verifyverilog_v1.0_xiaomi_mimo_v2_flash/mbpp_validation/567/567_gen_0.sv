module is_sorted_check (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state;
    reg [3:0] idx;
    reg sorted_reg;
    reg [7:0] arr_reg [0:7];
    reg [3:0] len_reg;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            idx <= 4'd0;
            sorted_reg <= 1'b1;
            len_reg <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && len > 4'd1) begin
                        state <= LOAD;
                    end else if (start && len <= 4'd1) begin
                        result <= 1'b1;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                LOAD: begin
                    // Capture inputs into array
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    len_reg <= len;
                    idx <= 4'd1;
                    sorted_reg <= 1'b1;
                    state <= CHECK;
                end
                
                CHECK: begin
                    // Compare current pair
                    if (arr_reg[idx - 4'd1] > arr_reg[idx]) begin
                        sorted_reg <= 1'b0;
                    end
                    
                    // Check if last element
                    if (idx == len_reg - 4'd1) begin
                        result <= sorted_reg;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        idx <= idx + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule