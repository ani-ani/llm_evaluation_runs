module check_min_heap(
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
    input wire [2:0] len,
    output reg is_heap,
    output reg done
);

    // FSM states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_NODE = 3'd1;
    localparam [2:0] COMPLETE = 3'd2;

    reg [2:0] state;
    reg [2:0] current_idx;
    reg [7:0] arr_reg_0;
    reg [7:0] arr_reg_1;
    reg [7:0] arr_reg_2;
    reg [7:0] arr_reg_3;
    reg [7:0] arr_reg_4;
    reg [7:0] arr_reg_5;
    reg [7:0] arr_reg_6;
    reg [7:0] arr_reg_7;
    reg [2:0] len_reg;
    
    // Combinational signals
    wire [2:0] left_idx;
    wire [2:0] right_idx;
    wire has_left;
    wire has_right;
    wire left_ok;
    wire right_ok;
    wire [7:0] current_val;
    wire [7:0] left_val;
    wire [7:0] right_val;

    assign left_idx = (current_idx << 1) + 3'd1;
    assign right_idx = (current_idx << 1) + 3'd2;
    
    assign has_left = (left_idx < len_reg);
    assign has_right = (right_idx < len_reg);
    
    assign current_val = (current_idx == 3'd0) ? arr_reg_0 :
                         (current_idx == 3'd1) ? arr_reg_1 :
                         (current_idx == 3'd2) ? arr_reg_2 :
                         (current_idx == 3'd3) ? arr_reg_3 :
                         (current_idx == 3'd4) ? arr_reg_4 :
                         (current_idx == 3'd5) ? arr_reg_5 :
                         (current_idx == 3'd6) ? arr_reg_6 : arr_reg_7;

    assign left_val = (left_idx == 3'd0) ? arr_reg_0 :
                      (left_idx == 3'd1) ? arr_reg_1 :
                      (left_idx == 3'd2) ? arr_reg_2 :
                      (left_idx == 3'd3) ? arr_reg_3 :
                      (left_idx == 3'd4) ? arr_reg_4 :
                      (left_idx == 3'd5) ? arr_reg_5 :
                      (left_idx == 3'd6) ? arr_reg_6 : arr_reg_7;

    assign right_val = (right_idx == 3'd0) ? arr_reg_0 :
                       (right_idx == 3'd1) ? arr_reg_1 :
                       (right_idx == 3'd2) ? arr_reg_2 :
                       (right_idx == 3'd3) ? arr_reg_3 :
                       (right_idx == 3'd4) ? arr_reg_4 :
                       (right_idx == 3'd5) ? arr_reg_5 :
                       (right_idx == 3'd6) ? arr_reg_6 : arr_reg_7;
    
    assign left_ok = ~has_left || (current_val <= left_val);
    assign right_ok = ~has_right || (current_val <= right_val);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_heap <= 1'b1;
            done <= 1'b0;
            current_idx <= 3'd0;
            len_reg <= 3'd0;
            arr_reg_0 <= 8'd0;
            arr_reg_1 <= 8'd0;
            arr_reg_2 <= 8'd0;
            arr_reg_3 <= 8'd0;
            arr_reg_4 <= 8'd0;
            arr_reg_5 <= 8'd0;
            arr_reg_6 <= 8'd0;
            arr_reg_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_reg_0 <= arr_0;
                        arr_reg_1 <= arr_1;
                        arr_reg_2 <= arr_2;
                        arr_reg_3 <= arr_3;
                        arr_reg_4 <= arr_4;
                        arr_reg_5 <= arr_5;
                        arr_reg_6 <= arr_6;
                        arr_reg_7 <= arr_7;
                        len_reg <= len;
                        current_idx <= 3'd0;
                        is_heap <= 1'b1;
                        
                        if (len >= 3'd1) begin
                            state <= CHECK_NODE;
                        end else begin
                            done <= 1'b1;
                            state <= COMPLETE;
                        end
                    end
                end
                
                CHECK_NODE: begin
                    if (!left_ok || !right_ok) begin
                        is_heap <= 1'b0;
                        state <= COMPLETE;
                    end else if (has_right) begin
                        current_idx <= left_idx;
                        state <= CHECK_NODE;
                    end else if (has_left) begin
                        state <= COMPLETE;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule