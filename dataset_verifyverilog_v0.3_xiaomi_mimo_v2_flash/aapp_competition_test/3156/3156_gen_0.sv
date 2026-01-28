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

localparam [2:0] IDLE = 3'd0;
localparam [2:0] START_PROCESS = 3'd1;
localparam [2:0] LOAD_ITEM = 3'd2;
localparam [2:0] WAIT_MASK = 3'd3;
localparam [2:0] COMPUTE_DP = 3'd4;
localparam [2:0] NEXT_STORE = 3'd5;
localparam [2:0] NEXT_ITEM = 3'd6;
localparam [2:0] SUM_RESULT = 3'd7;

reg [2:0] state;
reg [3:0] item_idx;
reg [STORE_ID_WIDTH-1:0] store_idx;
reg [1:0] dp_prev [0:MAX_STORES-1];
reg [1:0] dp_curr [0:MAX_STORES-1];
reg [DP_WIDTH:0] running_sum;
reg [DP_WIDTH:0] total_count;

function [1:0] saturate;
    input [DP_WIDTH:0] val;
    begin
        saturate = (val >= 2'd2) ? 2'd2 : val[1:0];
    end
endfunction

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 2'd0;
        item_idx <= 4'd0;
        store_idx <= {STORE_ID_WIDTH{1'b0}};
        running_sum <= {DP_WIDTH+1{1'b0}};
        total_count <= {DP_WIDTH+1{1'b0}};
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
                store_idx <= {STORE_ID_WIDTH{1'b0}};
                running_sum <= {DP_WIDTH+1{1'b0}};
                state <= LOAD_ITEM;
            end
            
            LOAD_ITEM: begin
                if (item_idx < list_length) begin
                    item_id_for_lut <= shopping_list[item_idx];
                    state <= WAIT_MASK;
                end else begin
                    state <= SUM_RESULT;
                end
            end
            
            WAIT_MASK: begin
                if (store_idx == {STORE_ID_WIDTH{1'b0}}) begin
                    if (item_idx == 4'd0) begin
                        if (store_mask[0]) begin
                            dp_prev[0] <= 2'd1;
                        end else begin
                            dp_prev[0] <= 2'd0;
                        end
                    end
                end
                
                if (item_idx > 4'd0) begin
                    state <= COMPUTE_DP;
                end else begin
                    if (store_idx < MAX_STORES[STORE_ID_WIDTH-1:0]) begin
                        store_idx <= store_idx + {STORE_ID_WIDTH{1'b0}} + 1;
                        if (store_idx == MAX_STORES[STORE_ID_WIDTH-1:0] - 1) begin
                            item_idx <= item_idx + 1;
                            store_idx <= {STORE_ID_WIDTH{1'b0}};
                            state <= LOAD_ITEM;
                        end else begin
                            state <= WAIT_MASK;
                        end
                    end else begin
                        item_idx <= item_idx + 1;
                        store_idx <= {STORE_ID_WIDTH{1'b0}};
                        state <= LOAD_ITEM;
                    end
                end
            end
            
            COMPUTE_DP: begin
                if (store_idx < MAX_STORES[STORE_ID_WIDTH-1:0]) begin
                    running_sum <= running_sum + dp_prev[store_idx];
                    if (store_mask[store_idx]) begin
                        dp_curr[store_idx] <= saturate(running_sum + dp_prev[store_idx]);
                    end else begin
                        dp_curr[store_idx] <= 2'd0;
                    end
                    store_idx <= store_idx + {STORE_ID_WIDTH{1'b0}} + 1;
                    if (store_idx == MAX_STORES[STORE_ID_WIDTH-1:0] - 1) begin
                        for (i = 0; i < MAX_STORES; i = i + 1) begin
                            dp_prev[i] <= dp_curr[i];
                        end
                        item_idx <= item_idx + 1;
                        store_idx <= {STORE_ID_WIDTH{1'b0}};
                        running_sum <= {DP_WIDTH+1{1'b0}};
                        if (item_idx == list_length - 1) begin
                            state <= SUM_RESULT;
                        end else begin
                            state <= LOAD_ITEM;
                        end
                    end else begin
                        state <= COMPUTE_DP;
                    end
                end else begin
                    state <= WAIT_MASK;
                end
            end
            
            SUM_RESULT: begin
                total_count <= {DP_WIDTH+1{1'b0}};
                for (i = 0; i < MAX_STORES; i = i + 1) begin
                    total_count <= saturate(total_count + dp_prev[i]);
                end
                if (total_count == {DP_WIDTH+1{1'b0}}) begin
                    result <= 2'd0;
                end else if (total_count == 1) begin
                    result <= 2'd1;
                end else begin
                    result <= 2'd2;
                end
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule