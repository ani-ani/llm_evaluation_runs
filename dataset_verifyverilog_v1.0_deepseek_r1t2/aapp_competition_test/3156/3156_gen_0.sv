module shopping_path #(
    parameter MAX_STORES = 8,
    parameter MAX_ITEMS = 16,
    parameter ITEM_ID_WIDTH = 8,
    parameter STORE_ID_WIDTH = 3,
    parameter DP_WIDTH = 2
)(
    input clk,
    input rst_n,
    input start,
    input [ITEM_ID_WIDTH-1:0] shopping_list [0:MAX_ITEMS-1],
    input [3:0] list_length,
    output reg [ITEM_ID_WIDTH-1:0] item_id_for_lut,
    input [MAX_STORES-1:0] store_mask,
    output reg [1:0] result,
    output reg done
);

    localparam [2:0] 
        IDLE         = 3'd0,
        START_PROCESS= 3'd1,
        LOAD_ITEM    = 3'd2,
        WAIT_MASK    = 3'd3,
        COMPUTE_DP   = 3'd4,
        SUM_RESULT   = 3'd5,
        DONE_STATE   = 3'd6;

    reg [2:0] state;
    reg [3:0] item_idx;
    reg [2:0] store_idx;
    reg [1:0] dp_prev [0:MAX_STORES-1];
    reg [1:0] dp_curr [0:MAX_STORES-1];
    reg [DP_WIDTH:0] running_sum;
    reg [DP_WIDTH:0] total_count;
    integer i;

    function [1:0] saturate;
        input [DP_WIDTH:0] val;
        saturate = (val >= 3'd2) ? 2'd2 : val[1:0];
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 2'd0;
            item_idx <= 4'd0;
            store_idx <= 3'd0;
            running_sum <= {(DP_WIDTH+1){1'b0}};
            total_count <= {(DP_WIDTH+1){1'b0}};
            item_id_for_lut <= {ITEM_ID_WIDTH{1'b0}};
            for (i = 0; i < MAX_STORES; i = i + 1) begin
                dp_prev[i] <= 2'd0;
                dp_curr[i] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= START_PROCESS;
                    end
                end
                
                START_PROCESS: begin
                    item_idx <= 4'd0;
                    store_idx <= 3'd0;
                    running_sum <= {(DP_WIDTH+1){1'b0}};
                    state <= LOAD_ITEM;
                end
                
                LOAD_ITEM: begin
                    item_id_for_lut <= shopping_list[item_idx];
                    store_idx <= 3'd0;
                    state <= WAIT_MASK;
                end
                
                WAIT_MASK: begin
                    if (item_idx == 0) begin
                        if (store_mask[store_idx]) dp_prev[store_idx] <= 2'd1;
                        else dp_prev[store_idx] <= 2'd0;
                    end
                    
                    store_idx <= store_idx + 1;
                    
                    if (store_idx == MAX_STORES-1) begin
                        if (item_idx == 0) begin
                            item_idx <= item_idx + 1;
                            state <= LOAD_ITEM;
                        end
                        else begin
                            for (i = 0; i < MAX_STORES; i = i + 1) begin
                                dp_prev[i] <= dp_curr[i];
                                dp_curr[i] <= 2'd0;
                            end
                            if (item_idx < list_length - 1) begin
                                item_idx <= item_idx + 1;
                                state <= LOAD_ITEM;
                            end
                            else begin
                                state <= SUM_RESULT;
                            end
                        end
                    end
                    else begin
                        if (item_idx != 0) state <= COMPUTE_DP;
                        else state <= WAIT_MASK;
                    end
                end
                
                COMPUTE_DP: begin
                    running_sum <= running_sum + dp_prev[store_idx];
                    if (store_mask[store_idx]) 
                        dp_curr[store_idx] <= saturate(running_sum + dp_prev[store_idx]);
                    else 
                        dp_curr[store_idx] <= 2'd0;
                    state <= WAIT_MASK;
                end
                
                SUM_RESULT: begin
                    total_count <= {(DP_WIDTH+1){1'b0}};
                    for (i = 0; i < MAX_STORES; i = i + 1) begin
                        total_count <= saturate(total_count + dp_prev[i]);
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    case (total_count)
                        0: result <= 2'd0;
                        1: result <= 2'd1;
                        default: result <= 2'd2;
                    endcase
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule