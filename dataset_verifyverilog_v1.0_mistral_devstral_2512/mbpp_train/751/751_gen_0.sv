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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_NODE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [2:0] current_idx;
    reg [7:0] arr_reg [0:7];
    reg [2:0] len_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational signals
    wire [2:0] left_idx;
    wire [2:0] right_idx;
    wire has_left;
    wire has_right;
    wire left_ok;
    wire right_ok;

    assign left_idx = (current_idx << 1) + 1;
    assign right_idx = (current_idx << 1) + 2;
    
    assign has_left = (left_idx < len_reg);
    assign has_right = (right_idx < len_reg);
    
    assign left_ok = ~has_left || (arr_reg[current_idx] <= arr_reg[left_idx]);
    assign right_ok = ~has_right || (arr_reg[current_idx] <= arr_reg[right_idx]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_heap <= 1'b1;
            done <= 1'b0;
            current_idx <= 3'd0;
            len_reg <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        len_reg <= len;
                        current_idx <= 3'd0;
                        is_heap <= 1'b1;
                        cycle_count <= 8'd0;
                        
                        if (len >= 3'd1) begin
                            state <= CHECK_NODE;
                        end else begin
                            done <= 1'b1;
                            state <= COMPLETE;
                        end
                    end
                end
                
                CHECK_NODE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!left_ok || !right_ok) begin
                        is_heap <= 1'b0;
                        state <= COMPLETE;
                    end else if (has_left) begin
                        current_idx <= left_idx;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= COMPLETE;
                        end
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