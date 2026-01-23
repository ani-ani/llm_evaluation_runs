module unique_product (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] CHECK  = 3'd1;
    localparam [2:0] VERIFY = 3'd2;
    localparam [2:0] ADD    = 3'd3;
    localparam [2:0] CALC   = 3'd4;
    localparam [2:0] DONE   = 3'd5;
    localparam [2:0] NEXT   = 3'd6;
    localparam [2:0] SKIP   = 3'd7;
    
    reg [2:0] state;
    reg [2:0] i;
    reg [2:0] j;
    reg [7:0] unique_arr[7:0];
    reg [2:0] unique_count;
    reg [31:0] product;
    reg found;
    reg [7:0] current_val;
    
    // Function to get array element by index
    function automatic [7:0] get_arr_element;
        input [2:0] idx;
        input [7:0] a0, a1, a2, a3, a4, a5, a6, a7;
        begin
            case (idx)
                3'd0: get_arr_element = a0;
                3'd1: get_arr_element = a1;
                3'd2: get_arr_element = a2;
                3'd3: get_arr_element = a3;
                3'd4: get_arr_element = a4;
                3'd5: get_arr_element = a5;
                3'd6: get_arr_element = a6;
                3'd7: get_arr_element = a7;
                default: get_arr_element = 8'd0;
            endcase
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            unique_count <= 3'd0;
            product <= 32'd1;
            found <= 1'b0;
            current_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 3'd0;
                        unique_count <= 3'd0;
                        product <= 32'd1;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (i < len && i < 4'd8) begin
                        if (unique_count == 3'd0) begin
                            state <= ADD;
                        end else begin
                            j <= 3'd0;
                            found <= 1'b0;
                            current_val <= get_arr_element(i, arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7);
                            state <= VERIFY;
                        end
                    end else begin
                        j <= 3'd0;
                        state <= CALC;
                    end
                end
                
                VERIFY: begin
                    if (j < unique_count) begin
                        if (unique_arr[j] == current_val) begin
                            found <= 1'b1;
                            state <= SKIP;
                        end else begin
                            if (j == unique_count - 1) begin
                                state <= ADD;
                            end else begin
                                j <= j + 3'd1;
                            end
                        end
                    end else begin
                        state <= ADD;
                    end
                end
                
                SKIP: begin
                    i <= i + 3'd1;
                    state <= CHECK;
                end
                
                ADD: begin
                    unique_arr[unique_count] <= current_val;
                    unique_count <= unique_count + 3'd1;
                    i <= i + 3'd1;
                    state <= CHECK;
                end
                
                CALC: begin
                    if (j < unique_count) begin
                        product <= product * unique_arr[j];
                        j <= j + 3'd1;
                    end else begin
                        result <= product;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule