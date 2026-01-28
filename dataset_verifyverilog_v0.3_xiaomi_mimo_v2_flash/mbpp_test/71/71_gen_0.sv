module comb_sort (
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
    output reg [7:0] sorted_0,
    output reg [7:0] sorted_1,
    output reg [7:0] sorted_2,
    output reg [7:0] sorted_3,
    output reg [7:0] sorted_4,
    output reg [7:0] sorted_5,
    output reg [7:0] sorted_6,
    output reg [7:0] sorted_7,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] SORT = 3'd2;
localparam [2:0] DONE_STATE = 3'd3;

localparam [2:0] NUM_ELEMENTS = 3'd8;
localparam [5:0] MAX_CYCLES = 6'd64;

reg [2:0] state;
reg [2:0] next_state;

reg [7:0] buffer [0:7];
reg [7:0] gap;
reg [7:0] next_gap;
reg swapped;
reg next_swapped;
reg [2:0] i;
reg [2:0] next_i;
reg [5:0] cycle_count;
reg [5:0] next_cycle_count;

integer idx;

always @(*) begin
    next_state = state;
    next_gap = gap;
    next_swapped = swapped;
    next_i = i;
    next_cycle_count = cycle_count;
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD;
                next_cycle_count = 6'd0;
            end
        end
        
        LOAD: begin
            next_state = SORT;
            next_gap = 3'd8;
            next_swapped = 1'b1;
            next_i = 3'd0;
        end
        
        SORT: begin
            if (gap <= 8'd1 && !swapped) begin
                next_state = DONE_STATE;
            end else if (cycle_count >= MAX_CYCLES) begin
                next_state = DONE_STATE;
            end else begin
                if (i < (3'd8 - gap[2:0])) begin
                    next_i = i + 3'd1;
                    if (buffer[i] > buffer[i + gap[2:0]]) begin
                        next_swapped = 1'b1;
                    end
                end else begin
                    next_i = 3'd0;
                    next_cycle_count = cycle_count + 6'd1;
                    
                    if (gap > 8'd1) begin
                        next_gap = (gap * 8'd13) >> 3;
                        if (next_gap < 8'd1) begin
                            next_gap = 8'd1;
                        end
                    end else begin
                        next_gap = 8'd0;
                    end
                    
                    next_swapped = 1'b0;
                end
            end
        end
        
        DONE_STATE: begin
            if (!start) begin
                next_state = IDLE;
            end
        end
        
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        gap <= 8'd0;
        swapped <= 1'b0;
        i <= 3'd0;
        cycle_count <= 6'd0;
        buffer[0] <= 8'd0;
        buffer[1] <= 8'd0;
        buffer[2] <= 8'd0;
        buffer[3] <= 8'd0;
        buffer[4] <= 8'd0;
        buffer[5] <= 8'd0;
        buffer[6] <= 8'd0;
        buffer[7] <= 8'd0;
        sorted_0 <= 8'd0;
        sorted_1 <= 8'd0;
        sorted_2 <= 8'd0;
        sorted_3 <= 8'd0;
        sorted_4 <= 8'd0;
        sorted_5 <= 8'd0;
        sorted_6 <= 8'd0;
        sorted_7 <= 8'd0;
    end else begin
        state <= next_state;
        gap <= next_gap;
        swapped <= next_swapped;
        i <= next_i;
        cycle_count <= next_cycle_count;
        
        if (state == LOAD) begin
            buffer[0] <= arr_0;
            buffer[1] <= arr_1;
            buffer[2] <= arr_2;
            buffer[3] <= arr_3;
            buffer[4] <= arr_4;
            buffer[5] <= arr_5;
            buffer[6] <= arr_6;
            buffer[7] <= arr_7;
        end
        
        if (state == SORT && i < (3'd8 - gap[2:0])) begin
            if (buffer[i] > buffer[i + gap[2:0]]) begin
                buffer[i] <= buffer[i + gap[2:0]];
                buffer[i + gap[2:0]] <= buffer[i];
            end
        end
        
        if (state == DONE_STATE) begin
            sorted_0 <= buffer[0];
            sorted_1 <= buffer[1];
            sorted_2 <= buffer[2];
            sorted_3 <= buffer[3];
            sorted_4 <= buffer[4];
            sorted_5 <= buffer[5];
            sorted_6 <= buffer[6];
            sorted_7 <= buffer[7];
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
end

endmodule