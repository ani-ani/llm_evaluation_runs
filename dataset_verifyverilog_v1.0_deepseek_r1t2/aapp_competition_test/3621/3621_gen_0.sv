module compute_sum #(
    parameter N = 8,
    parameter COLOR_WIDTH = 9,
    parameter SUM_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [COLOR_WIDTH-1:0] color [0:N-1][0:N-1],
    output reg [SUM_WIDTH-1:0] sum,
    output reg done
);
    reg [7:0] subset;
    reg [7:0] inner;
    reg [SUM_WIDTH-1:0] total;
    reg [7:0] max_size;
    reg [7:0] pair_i, pair_j;
    reg [COLOR_WIDTH-1:0] first_color;
    reg mono_ok;
    
    reg [3:0] state;
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_OUTER = 4'd1;
    localparam [3:0] INIT_INNER = 4'd2;
    localparam [3:0] CHECK_SUBMASK = 4'd3;
    localparam [3:0] START_MONO = 4'd4;
    localparam [3:0] CHECK_PAIR = 4'd5;
    localparam [3:0] NEXT_PAIR = 4'd6;
    localparam [3:0] UPDATE_MAX = 4'd7;
    localparam [3:0] NEXT_INNER = 4'd8;
    localparam [3:0] ADD_SUM = 4'd9;
    localparam [3:0] NEXT_OUTER = 4'd10;
    localparam [3:0] DONE = 4'd11;
    
    function [7:0] popcnt;
        input [7:0] mask;
        integer k;
        begin
            popcnt = 8'd0;
            for (k=0; k<N; k=k+1)
                if (mask[k]) popcnt = popcnt + 8'd1;
        end
    endfunction
    
    function is_subset;
        input [7:0] m1, m2;
        begin
            is_subset = ((m1 & m2) == m1);
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum <= {SUM_WIDTH{1'b0}};
            done <= 1'b0;
            subset <= 8'd0;
            inner <= 8'd0;
            total <= {SUM_WIDTH{1'b0}};
            max_size <= 8'd0;
            pair_i <= 8'd0;
            pair_j <= 8'd0;
            first_color <= {COLOR_WIDTH{1'b0}};
            mono_ok <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= INIT_OUTER;
                end
                
                INIT_OUTER: begin
                    subset <= 8'd1;
                    total <= {SUM_WIDTH{1'b0}};
                    state <= INIT_INNER;
                end
                
                INIT_INNER: begin
                    inner <= 8'd1;
                    max_size <= 8'd1;
                    state <= CHECK_SUBMASK;
                end
                
                CHECK_SUBMASK: begin
                    if (inner > 8'd255) state <= ADD_SUM;
                    else if (is_subset(inner, subset)) state <= START_MONO;
                    else state <= NEXT_INNER;
                end
                
                START_MONO: begin
                    mono_ok <= 1'b1;
                    first_color <= {COLOR_WIDTH{1'b0}};
                    pair_i <= 8'd0;
                    pair_j <= 8'd1;
                    state <= CHECK_PAIR;
                end
                
                CHECK_PAIR: begin
                    if (pair_i >= N) begin
                        if (mono_ok) state <= UPDATE_MAX;
                        else state <= NEXT_INNER;
                    end
                    else begin
                        if (inner[pair_i] && inner[pair_j] && (pair_i != pair_j)) begin
                            if (color[pair_i][pair_j] != first_color) begin
                                if (first_color == {COLOR_WIDTH{1'b0}})
                                    first_color <= color[pair_i][pair_j];
                                else
                                    mono_ok <= 1'b0;
                            end
                        end
                        state <= NEXT_PAIR;
                    end
                end
                
                NEXT_PAIR: begin
                    if (pair_j < (N-1)) begin
                        pair_j <= pair_j + 8'd1;
                    end
                    else begin
                        pair_j <= pair_i + 8'd2;
                        pair_i <= pair_i + 8'd1;
                    end
                    state <= CHECK_PAIR;
                end
                
                UPDATE_MAX: begin
                    if (popcnt(inner) > max_size)
                        max_size <= popcnt(inner);
                    state <= NEXT_INNER;
                end
                
                NEXT_INNER: begin
                    inner <= inner + 8'd1;
                    state <= CHECK_SUBMASK;
                end
                
                ADD_SUM: begin
                    total <= total + max_size;
                    state <= NEXT_OUTER;
                end
                
                NEXT_OUTER: begin
                    subset <= subset + 8'd1;
                    if (subset == 8'd255)
                        state <= DONE;
                    else
                        state <= INIT_INNER;
                end
                
                DONE: begin
                    sum <= total;
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule